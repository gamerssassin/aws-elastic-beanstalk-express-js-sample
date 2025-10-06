// app.js
const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.get('/', (req, res) => res.send('Hello World!'));

// Only start server when run directly 
if (require.main === module) {
  app.listen(port, () => console.log(`App running on http://localhost:${port}`));
}

// Export for tests
module.exports = app;
