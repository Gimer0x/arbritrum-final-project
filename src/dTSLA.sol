// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_3_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/utils/Strings.sol";

contract dTSLA is ConfirmedOwner, FunctionsClient, ERC20 {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;
    
    error dTSLA__NotEnoughCollateral();
    error dTSLA__RedemptionFailed();
    error dTSLA__BelowMinimumRedemption();
    
    address constant ARBITRUM_SEPOLIA_FUNCTIONS_ROUTER = 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
    bytes32 constant DON_ID = hex"66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000";
    // This hard-coded value isn't great engineering. Please check with your brokerage
    // and update accordingly
    // For example, for Alpaca: https://alpaca.markets/support/crypto-wallet-faq
    uint256 public constant MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT = 100e18;

    // Maininet
    // address constant ARBITRUM_TSLA_PRICE_FEED = 0x3609baAa0a9b1f0FE4d6CC01884585d0e191C3E3;

    // Arbitrum Sepolia: Link/USD only for testing purposes. 
    address constant ARBITRUM_TSLA_PRICE_FEED = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;

    // Arbitrum Sepolia
    address constant ARBITRUM_USD_USDC_PRICE_FEED = 0x0153002d20B96532C639313c2d54c3dA09109309;

    address constant ARBITRUM_SEPOLIA_TOKEN = 0xca638E545b066FEE9Ef60cE7f37f0BBE08a8F1AF;
    
    uint32 constant GAS_LIMIT = 300000;
    uint64 immutable i_subId;
    // 200% collateral ratio, we alays want to be overcollateralized. 
    uint256 public constant COLLATERAL_RATIO = 200;
    uint256 public constant COLLATERAL_PRECISION = 100;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 10 ** 18;

    uint8 donHostedSecretsSlotID = 0;
    uint64 donHostedSecretsVersion = 1712769962;

    string private s_mintSourceCode;
    string private s_redeemSourceCode;

    enum MintOrRedeem {
        mint,
        redeem
    }

    struct dTslaRequest {
        uint256 amountOfToken;
        address requester;
        MintOrRedeem mintOrRedeem;
    }

    mapping(bytes32 requestId=> dTslaRequest) public s_requestIdToRequest;
    mapping(address user => uint256 amountAvailableForWithdrawal) private s_userToWithdrawalAmount;

    constructor(
        string memory _mintSourceCode, 
        uint64 _subId, 
        string memory _redeemSourceCode
    ) 
        ConfirmedOwner(msg.sender) 
        FunctionsClient(ARBITRUM_SEPOLIA_FUNCTIONS_ROUTER) 
        ERC20("dTSLA", "dTSLA")
    {
        s_mintSourceCode = _mintSourceCode;
        s_redeemSourceCode = _redeemSourceCode;
        i_subId = _subId;
    }

    ///  Send an HTTP request to:
    /// 1. Check how much TSLA is bought
    /// 2. If enough TSLA is in the alpaca account, 
    /// mint dTSLA to the user.
    /// Two transaction function.
    function sendMintRequest(uint256 _amount) external onlyOwner returns (bytes32) {
        FunctionsRequest.Request memory req;

        req.initializeRequestForInlineJavaScript(s_mintSourceCode);
        // Check if this is needed
        req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, DON_ID);

        s_requestIdToRequest[requestId] = dTslaRequest({
            amountOfToken: _amount,
            requester: msg.sender,
            mintOrRedeem: MintOrRedeem.mint
        });

        return requestId;
    }

    /// Return the amount of TSLA value (in USDC) is stored in our broker.
    /// If we have enough collateral, mint the requested amount of dTSLA to the user.
    function _mintFullFillRequest(bytes32 _requestId, bytes memory response) internal {
        uint256 amountOfTokensToMint = s_requestIdToRequest[_requestId].amountOfToken;
        uint256 s_portfolioBalance = uint256(bytes32(response));

        // if TSLA collateral (how much TSLA we bought) > dTSLA to mint -> mint
        // How much TSLA in $$$ do we have?
        // How much TSLA in $$$ are we minting?

        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughCollateral();
        }

        if (amountOfTokensToMint != 0) {
            _mint(s_requestIdToRequest[_requestId].requester, amountOfTokensToMint);
        }

    }

    /// @notice User sends a request to sell TSLA for USDC (redemption token)
    /// This will, have the chainlink function call our alpaca (bank)
    /// and do the following:
    /// 1. Sell TSLA on the brokerage
    /// 2. Buy USDC on the brokerage
    /// 3. Send USDC to this contract for the user to claim.
    function _sendRedeemRequest(uint256 _amountdTsla) internal {
        // Should be able to just always redeem?
        // @audit potential exploit here, where if a user can redeem more than the collateral amount
        // Checks
        // Remember, this has 18 decimals
        uint256 amountTslaInUsdc = getUsdcValueOfUsd(getUsdValueOfTsla(_amountdTsla));

        if (amountTslaInUsdc < MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT) {
            revert dTSLA__BelowMinimumRedemption();
        }

        // Internal Effects
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSourceCode); // Initialize the request with JS code
        string[] memory args = new string[](2);
        // Sell this much amount of TSLA
        args[0] = _amountdTsla.toString();
        // The transaction will fail if it's outside of 2% slippage
        // This could be a future improvement to make the slippage a parameter by someone
        // send this much amount of USDC to the broker
        args[1] = amountTslaInUsdc.toString();
        req.setArgs(args);

        // Send the request and store the request ID
        // We are assuming requestId is unique
        bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, DON_ID);
        s_requestIdToRequest[requestId] = dTslaRequest(_amountdTsla, msg.sender, MintOrRedeem.redeem);

        // External Interactions
        _burn(msg.sender, _amountdTsla);
    }

    function _redeemFullFillRequest(bytes32 _requestId, bytes memory response) internal {
        // Assume for noe this has 18 decimals
        uint256 usdcAmount = uint256(bytes32(response));
        //uint256 usdcAmountWad;

        /*if (i_redemptionCoinDecimals < 18) {
            usdcAmountWad = usdcAmount * (10 ** (18 - i_redemptionCoinDecimals));
        }*/
        if (usdcAmount == 0) {
            // revert dTSLA__RedemptionFailed();
            // Redemption failed, we need to give them a refund of dTSLA
            // This is a potential exploit, look at this line carefully!!
            uint256 amountOfdTSLABurned = s_requestIdToRequest[_requestId].amountOfToken;
            _mint(s_requestIdToRequest[_requestId].requester, amountOfdTSLABurned);
            return;
        }

        s_userToWithdrawalAmount[s_requestIdToRequest[_requestId].requester] += usdcAmount;
    }

    function withdraw() external  {
        uint256 amountToWithdraw = s_userToWithdrawalAmount[msg.sender];
        s_userToWithdrawalAmount[msg.sender] = 0;
        // Send the user their USDC
        bool succ = ERC20(ARBITRUM_SEPOLIA_TOKEN).transfer(msg.sender, amountToWithdraw);
        require(succ, dTSLA__RedemptionFailed());
    }

    function _fulfillRequest(
        bytes32 _requestId, 
        bytes memory response, 
        bytes memory /* err */
    ) 
        internal 
        override
    {
        if (s_requestIdToRequest[_requestId].mintOrRedeem == MintOrRedeem.mint) {
            _mintFullFillRequest(_requestId, response);
            
        } else {
            _redeemFullFillRequest(_requestId, response);
            
        }
    }


    function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal view returns (uint256) {
        uint256 calculatedNewTotalValue = getCalculatedNewTotalValue(amountOfTokensToMint);
        return (calculatedNewTotalValue * COLLATERAL_RATIO) / COLLATERAL_PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/


    // The new expected total value in USD of all the dTSLA tokens combined. 
    function getCalculatedNewTotalValue(uint256 addedNumberOfTsla) public view returns (uint256) {
        return ((totalSupply() + addedNumberOfTsla) * getTslaPrice()) / PRECISION;
    }

    // TSLA USD has 8 decimal places, so we add an additional 10 decimal places
    function getTslaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ARBITRUM_TSLA_PRICE_FEED);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdValueOfTsla(uint256 tslaAmount) public view returns (uint256) {
        return (tslaAmount * getTslaPrice()) / PRECISION;
    }

    function getUsdcValueOfUsd(uint256 usdAmount) public view returns (uint256) {
        return (usdAmount * PRECISION) / getUsdcPrice();
    }

    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ARBITRUM_USD_USDC_PRICE_FEED);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getTotalUsdValue() public view returns (uint256) {
        return (totalSupply() * getTslaPrice()) / PRECISION;
    }

    function getRequest(bytes32 requestId) public view returns (dTslaRequest memory) {
        return s_requestIdToRequest[requestId];
    }

    function getWithdrawalAmount(address user) public view returns (uint256) {
        return s_userToWithdrawalAmount[user];
    }

    function getMintSourceCode() public view returns (string memory) {
        return s_mintSourceCode;
    }
    
    function getRedeemSourceCode() public view returns (string memory) {
        return s_redeemSourceCode;
    }

}

