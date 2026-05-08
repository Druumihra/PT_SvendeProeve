import express from 'express';

import jwt from 'jsonwebtoken';
import cors from 'cors';
import { prisma } from './lib/prisma';

const app = express();
app.use(express.json());
app.use(
  cors({
    origin: 'http://localhost:8080',
    credentials: true,
  }),
);
app.use(express.urlencoded({ extended: true }));

app.post('/createGroup')

app.post('/inviteUserToGroup')

app.post('/')





const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
