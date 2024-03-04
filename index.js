import http from 'http';
import { createRouter } from 'next-connect';

const port = process.env.HTTP_PORT || 3000;

const handler = createRouter()
  .get('/iconicactions', (req, res) => {
    res.end('OK');
  }).handler();

http.createServer(handler).listen(port);
