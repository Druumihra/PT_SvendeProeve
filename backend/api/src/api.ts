import express from 'express';

import jwt from 'jsonwebtoken';
import cors from 'cors';
import { prisma } from '../lib/prisma';

const app = express();
app.use(express.json());
app.use(
  cors({
    origin: 'http://localhost:8080',
    credentials: true,
  }),
);
app.use(express.urlencoded({ extended: true }));

app.post('/createGroup', async (req: any, res: any) => {
  prisma.groups.create({
    data: {
      name,
    },
  });
});

app.post('/inviteUserToGroup', async (req: any, res: any) => {});

app.post('/challenge/create', async (req: any, res: any) => {});

app.post('/challenge/edit', async (req: any, res: any) => {});

app.post('/challenge/end', async (req: any, res: any) => {});

app.post('/deleteChallenge', async (req: any, res: any) => {});

app.post('/deleteGroup', async (req: any, res: any) => {});

app.post('/challenge/submitResult', async (req: any, res: any) => {});

app.post('/challenge/getPlayerPoints', async (req: any, res: any) => {});

const PORT = 3050;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
