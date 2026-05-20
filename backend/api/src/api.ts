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
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  prisma.groups.create({
    data: {
      name: req.body.groupName,
    },
  });
});

app.post('/addUserToGroup', async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  await prisma.groups.update({
    where: {
      id: req.body.groupId,
    },
    data: { }
})
  
});

app.post('/challenge/create', async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  await prisma.challenges.create({
    where: {
      id: req.body.challengeId,
    },
    data: {
      name: req.body.challengeName,
      description: req.body.challengeDescription,
      groupsId: req.body.groupId,
      active: true,

    }
});
})


app.post('/challenge/edit', async (req: any, res: any) => {});

app.post('/challenge/end', async (req: any, res: any) => {
    if (!req.body) {/* Error message */}
    await prisma.challenges.update({
        where: {
            id: req.body.challengeId,
        },
        data: {
            active: false,
        },
    });
});

app.post('/deleteChallenge', async (req: any, res: any) => {
  if (!req.body) {/* Error message */} 
  prisma.challenges.delete({
      where: {
          id: req.body.challengeId,
      },
  });

});

app.post('/deleteGroup', async (req: any, res: any) => {
if (!req.body) {/* Error message */}
prisma.groups.delete({
    where: {
        id: req.body.groupId,
    },
  })
});

app.post('/challenge/submitResult', async (req: any, res: any) => {});

app.post('/challenge/getPlayerPoints', async (req: any, res: any) => {});

const PORT = 3050;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
