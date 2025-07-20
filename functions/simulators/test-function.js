// Simple test to verify Functions code works
const fs = require('fs');

// Read your Functions source code
const sourceCode = fs.readFileSync('./functions/sources/alpacaBalance.js', 'utf8');

console.log('=== Functions Source Code ===');
console.log(sourceCode);
console.log('\n=== Code Analysis ===');

// Check for common issues
const checks = {
  hasSecretsCheck: sourceCode.includes('secrets.alpacaKey'),
  hasHttpRequest: sourceCode.includes('Functions.makeHttpRequest'),
  hasHeaders: sourceCode.includes('APCA-API-KEY-ID'),
  hasReturn: sourceCode.includes('Functions.encodeUint256'),
  hasErrorHandling: sourceCode.includes('response.error')
};

console.log('✅ Secrets validation:', checks.hasSecretsCheck);
console.log('✅ HTTP request:', checks.hasHttpRequest);
console.log('✅ Headers setup:', checks.hasHeaders);
console.log('✅ Return encoding:', checks.hasReturn);
console.log('✅ Error handling:', checks.hasErrorHandling);