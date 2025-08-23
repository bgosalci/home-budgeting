const fs = require('fs');
if (!fs.existsSync('index.html')) {
  throw new Error('index.html not found');
}
console.log('index.html exists');
