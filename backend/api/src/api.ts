import express from 'express';
import jwt from 'jsonwebtoken';
import cors from 'cors';
import { prisma } from '../lib/prisma';
import { Blob } from 'buffer';
import fs from 'node:fs';

// import type {
//   UsersModel as user,
//   GroupsModel as group,
//   ChallengesModel as challenge,
// } from '../generated/prisma/models';

const app = express();
app.use(express.json());
app.use(
  cors({
    origin: '*',
    credentials: true,
  }),
);
app.use(express.urlencoded({ extended: true }));

app.post('/createUser', async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Invalid request body.');
  } else {
    await prisma.users.create({
      data: {
        name: req.body.username,
        id: req.body.id,
      },
    });
    res.status(200).json('User created successfully.');
  }
});

// apply auth to all routes below this middleware
async function auth(req: any, res: any, next: any) {
  if (!req.headers['cookie']) {
    res.status(401).json('Please log in');
  } else {
    let token = req.headers['cookie'].split('session=')[1];
    let response = await fetch('http://localhost:3050/verify', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        include: 'credentials',
        cookie: `session=${token}`,
      },
    });
    if (!response.ok) {
      res.status(401).json('Unauthorized');
    } else {
      next();
    }
  }
}

async function isgroupadmin(groupId: number, userId: number) {
  let result = await prisma.groupAdmins.findFirst({
    where: {
      groupId: groupId,
      usersId: userId,
    },
  });
  if (result != null) {
    return true;
  } else return false;
}

app.put('/edit/:id/user', auth, async (req: any, res: any) => {
  if (req.body.profilePicture) {
    const imageblob = new Blob([req.body.profilePicture], {
      type: 'image/png',
    });
  } else {
    const imageblob = undefined;
  }
  await prisma.users.update({
    where: { id: req.params.id },
    data: {
      username: req.body.username,
      profilePicture: imageblob,
    },
  });
  // maybe add a fetch to update email and password in auth
  if (req.body.email || req.body.password) {
    let response = await fetch('http://localhost:3050/updateAuth', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: req.body.email,
        password: req.body.password,
      }),
    });
    if (!response.ok) {
      res.status(500).json(response);
    }
  }
  res.status(200).json('Success');
});

// gets called from auth api
app.delete('/delete/:id/user', auth, async (req: any, res: any) => {
  await prisma.users.delete({
    where: { id: req.params.id },
    // data: {
    //   challengesresult: { deleteMany: { where: { userid: req.params.id } } },
    //   disconnect: { challengesresult: true, groups: true },
    // },
  });
});

app.get('/user/findUsers', auth, async (req: any, res: any) => {
  prisma.users.findMany({
    where: {
      name: { contains: req.body.username },
    },
  });
});

app.get('/user/getUser', auth, async (req: any, res: any) => {
  let result = prisma.users.findMany({
    where: { name: { contains: req.body.query } },
  });
  res.status(200).json(result);
});

//rewrite
app.post('/user/addFriend', auth, async (req: any, res: any) => {
  prisma.friends.create({
    data: {
      friendId: req.body.friendId,
      connect: {
        users: { id: req.body.userId },
      },
    },
  });
});

app.put('/user/acceptFriend', auth, async (req: any, res: any) => {
  prisma.friends.update({
    where: { friendId: req.body.friendId, usersId: req.body.userId },
    data: { accepted: true },
  });
});

app.delete('/user/removeFriend', auth, async (req: any, res: any) => {
  prisma.friends.delete({
    where: { friendId: req.body.friendId, usersId: req.body.userId },
  });
});

app.get('/user/getFriends', auth, async (req: any, res: any) => {
  const friendids = await prisma.users.findMany({
    where: { friends: { friendId: req.body.userId, accepted: true } },
    select: { friends: true },
  });
  // probs wont work
  const friends = await prisma.users.findUnique({
    where: {
      id: req.body.id,
      friends: { some: { usersId: req.body.userId, accepted: true } },
    },
    select: { name: true, id: true },
  });
});

app.post('/group/create', auth, async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }

  let result = await prisma.groups.create({
    data: {
      name: req.body.groupName,
      members: req.body.userId,
      admins: {
        create: { usersId: req.body.userId },
      },
    },
  });

  if (result === null || result === undefined) {
    res.status(500).json('An error occurred while creating the group.');
  } else {
    res.status(200).json('Group created successfully.');
  }
});

app.get('/group/:groupId/getMembers', auth, async (req: any, res: any) => {
  const members = await prisma.groups.findUnique({
    where: { id: req.params.groupId },
    select: { members: true },
  });
  res.status(200).json(members);
});

app.post('/group/:groupId/addUser', auth, async (req: any, res: any) => {
  if (!(await isgroupadmin(req.params.groupId, req.body.userId))) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  await prisma.groups.update({
    where: {
      id: req.params.groupId,
    },
    data: { members: req.body.userId },
  });
});

app.post('/group/:groupId/addAdmin', auth, async (req: any, res: any) => {
  if (!(await isgroupadmin(req.params.groupId, req.body.userId))) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  await prisma.groupAdmins.create({
    data: {
      admin: req.body.userId,
      group: { connect: { id: req.params.groupId } },
    },
  });
});

app.post('/group/:groupId/kickUser', auth, async (req: any, res: any) => {
  if (!(await isgroupadmin(req.params.groupId, req.body.userId))) {
    res.status(401).json('Unauthorized');
  }
  let result = await prisma.groups.delete({
    where: { name: req.body.username, id: req.params.groupId },
  });
  res.status(200).json(result);
});

app.post('/group/:groupId/delete', auth, async (req: any, res: any) => {
  if (!(await isgroupadmin(req.params.groupId, req.body.userId))) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Invalid request body.');
  }
  await prisma.groups.delete({
    where: {
      id: req.params.groupId,
    },
  });
});

app.put('/group/:groupId/edit', auth, async (req: any, res: any) => {
  if (!(await isgroupadmin(req.params.groupId, req.body.userId))) {
    res.status(401).json('Unauthorized');
  }
  await prisma.groups.update({
    where: {
      id: req.params.groupId,
    },
    data: req.body,
  });
});

app.post('/challenge/create', auth, async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  await prisma.challenges.create({
    data: {
      name: req.body.challengeName,
      description: req.body.challengeDescription,
      groupsId: req.body.groupId,
      active: true,
    },
  });
});

app.post('/challenges/:groupId/getAll', auth, async (req: any, res: any) => {
  const challenges = await prisma.challenges.findMany({
    where: {
      groupsId: req.params.groupId,
    },
    select: {
      name: true,
      description: true,
      id: true,
      active: true,
    },
  });
  res.json(challenges);
});

app.put('/challenge/:challengeId/edit', auth, async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Invalid request body.');
  } else {
    let check = await prisma.challenges.findFirst({
      where: {
        id: req.params.challengeId,
      },
    });
    if (check === null || check === undefined) {
      res.status(404).json('Challenge not found.');
    } else {
      await prisma.challenges.update({
        where: {
          id: req.params.challengeId,
        },
        data: {
          name: req.body.challengeName,
          description: req.body.challengeDescription,
          groupsId: req.body.groupId,
        },
      });
    }
  }
});

app.put('/challenge/:challengeId/end', auth, async (req: any, res: any) => {
  if (!(await isgroupadmin(req.body.groupId, req.body.userId))) {
    res.status(401).json('Unauthorized');
  } else {
    let result = await prisma.challenges.update({
      where: {
        id: req.params.challengeId,
      },
      data: {
        active: false,
      },
    });
    res.status(200).json(result);
  }
});

app.post('/challenge/:challengeId/delete', auth, async (req: any, res: any) => {
  if (!(await isgroupadmin(req.body.groupId, req.body.userId))) {
    res.status(401).json('Unauthorized');
  }
  await prisma.challenges.delete({
    where: {
      id: req.params.challengeId,
    },
  });
});

app.post('/challenge/:challengeId/submit', auth, async (req: any, res: any) => {
  let result = await prisma.challengesResult.create({
    data: {
      Result: req.body.result,
      User: {
        connect: {
          id: req.body.userId,
        },
      },
      Challenge: {
        connect: {
          id: req.params.challengeId,
        },
      },
    },
  });
  if (result === null || result === undefined) {
    res.status(500).json('An error occurred while submitting the result.');
  } else {
    res.status(200).json(result);
  }
});

app.get(
  '/challenge/:challengeId/getPlayerPoints',
  auth,
  async (req: any, res: any) => {
    await prisma.challengesResult.findMany({
      where: { challengesId: req.params.challengeId },
    });
  },
);

app.post('/challenge/:challengeId/createvote', auth, async (req: any, res: any) => {
  //should allow a group admin to create a vote for a challenge
  await prisma.challenges.update({
    where: {
      id: req.params.challengeId,
    },
    data: {
      votes: {
        create: [{ vote: req.body.vote }],
      },
    },
  });
  res.status(200).json('Vote sucessfully created.');
});

app.post('/challenge/:challengeId/vote', auth, async (req: any, res: any) => {
  if (req.body.vote.type) {
    res.status(400).json('Invalid vote value.');
  }
  let result = await prisma.votes.create({
    data: {
      User: { connect: { id: req.body.userId } },
      Challenge: { connect: { id: req.params.challengeId } },
      vote: req.body.vote,
    },
  });
  res.status(200).json(result);
});

const PORT = 3050;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
