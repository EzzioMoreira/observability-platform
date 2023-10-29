const express = require('express');
const fetch = require('isomorphic-fetch');

const app = express();
const port = 3000;

app.get('/', async (req, res) => {
  try {
    const response = await fetch('http://app-python-service:8000/');
    const data = await response.text();
    res.send(data);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send('Internal Server Error');
  }
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
