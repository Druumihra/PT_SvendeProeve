import express from 'express';
import jwt from 'jsonwebtoken';
import cors from 'cors';
import { prisma } from '../lib/prisma';
// import type {
//   UsersModel as user,
//   GroupsModel as group,
//   ChallengesModel as challenge,
// } from '../generated/prisma/models';

const app = express();
app.use(express.json());
app.use(
  cors({
    origin: 'http://localhost:8080',
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
        username: req.body.username,
        id: req.body.id,
      },
    });
  }
});

// apply auth to all routes below this middleware
async function auth(req: any) {
  let token = req.headers['cookie'].split('session=')[1];
  let res = await fetch('http://localhost:3050/verify', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      include: 'credentials',
      cookie: `session=${token}`,
    },
  });
  if (!res.ok) {
    return false;
  } else {
    return true;
  }
}

async function isgroupadmin(groupId: string, userId: string) {
  let result = await prisma.groupadmins.findFirst({
    where: {
      groupId: groupId,
      usersId: userId,
    },
  });
  if (result != null) {
    return true;
  } else return false;
}

app.put('/edit/:id/user', async (req: any, res: any) => {
  if (await auth(req.headers['cookie'].split('session=')[1])) {
    res.status(401).json('Unauthorized');
  } else {
    await prisma.users.update({
      where: { id: req.params.id },
      data: {
        username: req.body.username ?? prisma.skip,
        profilePicture: req.body.profilePicture ?? prisma.skip,
      },
    });

    // maybe add a fetch to update email and password in auth
    res.status(200).json('Success');
  }
});

app.delete('/delete/:id/user', async (req: any, res: any) => {
  if (!(await auth(req.headers['cookie'].split('session=')[1]))) {
    res.status(401).json('Unauthorized');
  } else {
    await prisma.users.delete({
      where: { id: req.params.id },
      data: {
        challenegesresult: { deleteMany: { where: { userid: req.params.id } } },
        disconnect: { challengesresult: true, groups: true },
      },
    });
  }
});

app.post('/group/create', async (req: any, res: any) => {
  if (await auth(req.headers['cookie'].split('session=')[1])) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }

  let result = await prisma.groups.create({
    data: {
      name: req.body.groupName,
      members: req.body.userId,
      admins: {
        create: [{ GroupAdmins: { usersId: req.body.userId } }],
      },
    },
  });
  if (result === null || result === undefined) {
    res.status(500).json('An error occurred while creating the group.');
  } else {
    res.status(200).json('Group created successfully.');
  }
});

app.get('/group/:groupId/getMembers', async (req: any, res: any) => {
  if (await auth(req.headers['cookie'].split('session=')[1])) {
    res.status(401).json('Unauthorized');
  }
  const members = await prisma.groups.findUnique({
    where: { id: req.params.groupId },
    select: { members: true },
  });
  res.json(members);
});

app.post('/group/:groupId/addUser', async (req: any, res: any) => {
  if (
    (await auth(req.headers['cookie'].split('session=')[1])) &&
    !(await isgroupadmin(req.params.groupId, req.body.userId))
  ) {
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

app.post('/group/:groupId/addAdmin', async (req: any, res: any) => {
  if (
    (await auth(req.headers['cookie'].split('session=')[1])) &&
    !(await isgroupadmin(req.params.groupId, req.body.userId))
  ) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  await prisma.groupadmins.create({
    data: {
      admin: req.body.userId,
      group: { connect: { id: req.params.groupId } },
    },
  });
});

app.post('/group/:groupId/kickUser', async (req: any, res: any) => {
  if (
    (await auth(req.headers['cookie'].split('session=')[1])) &&
    !(await isgroupadmin(req.params.groupId, req.body.userId))
  ) {
    res.status(401).json('Unauthorized');
  }
  let result = await prisma.groups.delete({
    where: { name: req.body.username, id: req.params.groupId },
  });
  res.status(200).json(result);
});

app.post('/group/:groupId/delete', async (req: any, res: any) => {
  if (
    (await auth(req.headers['cookie'].split('session=')[1])) &&
    !(await isgroupadmin(req.params.groupId, req.body.userId))
  ) {
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

app.put('/group/:groupId/edit', async (req: any, res: any) => {
  if (
    (await auth(req.headers['cookie'].split('session=')[1])) &&
    !(await isgroupadmin(req.params.groupId, req.body.userId))
  ) {
    res.status(401).json('Unauthorized');
  }
  await prisma.groups.update({
    where: {
      id: req.params.groupId,
    },
    data: req.body,
  });
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
    },
  });
});

app.post('/challenges/:groupId/getAll', async (req: any, res: any) => {
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

app.put('/challenge/:challengeId/edit', async (req: any, res: any) => {
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

app.put('/challenge/:challengeId/end', async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Invalid request body');
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

app.post('/challenge/:challengeId/delete', async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Invalid request body.');
  }
  await prisma.challenges.delete({
    where: {
      id: req.params.challengeId,
    },
  });
});

app.post('/challenge/:challengeId/submit', async (req: any, res: any) => {
  let result = await prisma.challengesresult.create({
    where: { challengeid: req.params.challengeId },
    data: {
      result: req.body.result,
      connect: { User: { id: req.body.userId } },
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
  async (req: any, res: any) => {
    await prisma.challengesresult.findmany({
      where: { challengeid: req.params.challengeId },
    });
  },
);

app.post('/challenge/:challengeId/createvote', async (req: any, res: any) => {
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

app.post('/challenge/:challengeId/vote', async (req: any, res: any) => {
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
