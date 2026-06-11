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

var dynamicCorsOptions = function (req: any, callback: any) {
  var corsOptions;
  if (req.path.startsWith('/auth/')) {
    corsOptions = {
      origin: `${process.env.AUTH_URL}`,
    };
  } else {
    corsOptions = {
      origin: '*',
      credentials: true,
    };
  }
  callback(null, corsOptions);
};

app.use(cors(dynamicCorsOptions));

app.use(express.urlencoded({ extended: true }));

app.post('/auth/createUser', async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Invalid request body.');
  } else {
    let result = await prisma.users.create({
      data: {
        name: req.body.username,
        id: req.body.id,
      },
    });
    res.status(200).json('User created successfully.');
  }
});

// let res = await fetch('http://localhost:3050/getPublicKey', {
//   method: 'GET',
//   headers: {
//     'Content-Type': 'application/json',
//   },
// });

async function auth(req: any, res: any, next: any) {
  if (!req.headers['cookie']) {
    res.status(401).json('Please log in');
  } else {
    let response = await fetch(`${process.env.AUTH_URL}/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        include: 'credentials',
        cookie: req.headers['cookie'],
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
  const imageblob = new Blob([req.body.profilePicture], {
    type: 'image/png',
  });

  await prisma.users.update({
    where: { id: req.params.id },
    data: {
      username: req.body.username,
      profilePicture: imageblob,
    },
  });

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

app.delete('/auth/delete/:id/user', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.id);
  let result = await prisma.users.delete({
    where: { id: id },
  });
  if (result != null) {
    res.status(200).json('Success');
  } else {
    res.status(500).json('error');
  }
});

app.post('/user/findUsers/:query', auth, async (req: any, res: any) => {
  let result = await prisma.users.findMany({
    where: {
      name: { contains: req.params.query },
    },
  });
  res.status(200).json(result);
});

app.get('/user/getUser/:id', auth, async (req: any, res: any) => {
  let result = await prisma.users.findUnique({
    where: { id: req.params.id },
  });
  res.status(200).json(result);
});

app.post('/user/addFriend', auth, async (req: any, res: any) => {
  prisma.users.update({
    where: { id: req.body.userId },
    data: {
      friends: {
        create: { friendid: req.body.friendId },
      },
    },
  });
  res.status(200).json('Friend request sent.');
});

app.put('/user/acceptFriend', auth, async (req: any, res: any) => {
  prisma.users.update({
    where: {
      id: req.body.userId,
      friends: { some: { friendid: req.body.friendId } },
    },
    data: { accepted: true },
  });

  res.status(200).json('Friend request accepted.');
});

app.delete('/user/removeFriend', auth, async (req: any, res: any) => {
  prisma.friends.delete({
    where: {
      usersId: req.body.userId,
      friendid: req.body.friendId,
    },
  });
  res.status(200).json('Friend removed.');
});

app.get('/user/getFriends', auth, async (req: any, res: any) => {
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
  //should use email rather than ID
  await prisma.groups.update({
    where: {
      id: req.params.groupId,
    },
    data: { members: req.body.userId },
  });
});

// make it request based like friends

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
      score: req.body.result,
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

// should return the points of all players in a challenge, ordered by score
app.get(
  '/challenge/:challengeId/scoreboard',
  auth,
  async (req: any, res: any) => {
    await prisma.challengesResult.findMany({
      where: { challengesId: req.params.challengeId },
      orderBy: { score: 'desc' },
    });
  },
);
//should get players points for a specific challenge, for the current week, ordered by date
app.get(
  '/challenge/:challengeId/getplayerpoints',
  auth,
  async (req: any, res: any) => {
    let result = await prisma.challengesResult.findMany({
      where: {
        challengesId: req.params.challengeId,
        usersId: req.body.userid,
      },
      select: { score: true, date: true },
      orderBy: { date: 'desc' },
    });

    //should sanitize result so that its total score per day for the last week

    res.status(200).json(result);
  },
);

app.post(
  '/challenge/:challengeId/createvote',
  auth,
  async (req: any, res: any) => {
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
  },
);

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
