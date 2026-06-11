import express from 'express';
import cors from 'cors';
import { prisma } from '../lib/prisma';

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
  // if (!req.headers['cookie'] || !req.headers['bearer']) {
  //   res.status(400).json('Please log in');
  // } else if (req.headers['cookie']) {
  //   let response = await fetch(`${process.env.AUTH_URL}/verify`, {
  //     method: 'POST',
  //     headers: {
  //       'Content-Type': 'application/json',
  //       include: 'credentials',
  //       cookie: req.headers['cookie'],
  //     },
  //   });
  //   if (!response.ok) {
  //     res.status(403).json('Unauthorized');
  //   } else {
  //     next();
  //   }
  // } else if (req.headers['bearer']) {
  //   let response = await fetch(`${process.env.AUTH_URL}/verify`, {
  //     method: 'POST',
  //     headers: {
  //       'Content-Type': 'application/json',
  //       include: 'credentials',
  //       cookie: req.headers['bearer'],
  //     },
  //   });
  //   if (!response.ok) {
  //     res.status(403).json('Unauthorized');
  //   } else {
  //     next();
  //   }
  // }
  next();
}

async function isgroupadmin(groupId: number, userId: number) {
  let result = await prisma.groupAdmins.findFirst({
    where: {
      groupsId: groupId,
      usersId: userId,
    },
  });
  if (result != null) {
    return true;
  } else return false;
}

app.put('/edit/:id/user', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.id);

  await prisma.users.update({
    where: { id: id },
    data: {
      username: req.body.username,
      profilePicture: req.body.picture,
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

app.get('/user/findUsers/:query', auth, async (req: any, res: any) => {
  let result = await prisma.users.findMany({
    where: {
      name: { contains: req.params.query },
    },
  });
  res.status(200).json(result);
});

app.get('/user/getUser/:id', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.id);
  let result = await prisma.users.findUnique({
    where: { id: id },
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

app.post('/user/getFriends', auth, async (req: any, res: any) => {
  const friends = await prisma.users.findUnique({
    where: {
      id: req.body.id,
      friends: { some: { usersId: req.body.userId, accepted: true } },
    },
    select: { name: true, id: true },
  });
  res.status(200).json(friends);
});

app.post('/group/create', auth, async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }

  let result = await prisma.groups.create({
    data: {
      name: req.body.groupName,
      usersId: req.body.userId,
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

app.get('/group/getgroups/:id', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.id);
  let result = await prisma.users.findUnique({
    where: { id: id },
    select: {
      groups: true,
    },
  });
  res.status(200).json(result);
});
app.get('/group/:groupId/getMembers', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);
  const members = await prisma.groups.findUnique({
    where: { id: id },
    select: { members: true },
  });
  res.status(200).json(members);
});

app.post('/group/:groupId/addUser', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);

  if (!(await isgroupadmin(id, req.body.adminId))) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  console.log(req.body);
  let result = await prisma.users.update({
    where: {
      id: req.body.userId,
    },
    data: {
      groups: {
        connect: {
          usersId_groupsId: { usersId: req.body.userId, groupsId: id },
        },
      },
    },
  });
  console.log(result);
  res.status(200).json('successfully added user');
});

app.post('/group/:groupId/addAdmin', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);

  if (!(await isgroupadmin(id, req.body.adminId))) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  await prisma.users.update({
    where: { id: req.body.userId },
    data: {
      admin: {
        connect: {
          usersId_groupsId: { usersId: req.body.userId, groupsId: id },
        },
      },
    },
  });
  res.status(200).json('success');
});

app.post('/group/:groupId/kickUser', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);

  if (!(await isgroupadmin(id, req.body.adminId))) {
    res.status(401).json('Unauthorized');
  }
  let result = await prisma.users.update({
    where: { id: req.body.usersid },
    data: {
      groups: {
        disconnect: {
          usersId_groupsId: {
            usersId: req.body.usersid,
            groupsId: id,
          },
        },
      },
    },
  });
  res.status(200).json(result);
});

app.post('/group/:groupId/delete', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);

  if (!(await isgroupadmin(id, req.body.adminId))) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Invalid request body.');
  }
  await prisma.groups.delete({
    where: {
      id: id,
    },
  });
});

app.put('/group/:groupId/edit', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);

  if (!(await isgroupadmin(id, req.body.userId))) {
    res.status(401).json('Unauthorized');
  }
  await prisma.groups.update({
    where: {
      id: id,
    },
    data: {
      name: req.body.name,
    },
  });
});

app.post('/challenge/create', auth, async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  await prisma.challenges.create({
    data: {
      name: req.body.challengeName,
      score: req.body.score,
      description: req.body.challengeDescription,
      active: true,
      group: { connect: { id: req.body.groupId } },
    },
  });
  res.status(200).json('Challenge created');
});

app.post('/challenges/:groupId/getAll', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);
  const challenges = await prisma.groups.findUnique({
    where: {
      name: req.body.name,
    },
    include: { challenges: true },
  });
  res.json(challenges);
});

app.put('/challenge/:challengeId/edit', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.challengeId);

  if (!req.body) {
    res.status(400).json('Invalid request body.');
  } else {
    let check = await prisma.challenges.findFirst({
      where: {
        id: id,
      },
    });
    if (check === null || check === undefined) {
      res.status(404).json('Challenge not found.');
    } else {
      await prisma.challenges.update({
        where: {
          id: id,
        },
        data: {
          score: req.body.score,
          name: req.body.challengeName,
          description: req.body.challengeDescription,
          groupsId: req.body.groupId,
        },
      });
    }
  }
});

app.put('/challenge/:challengeId/end', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.challengeId);

  if (!(await isgroupadmin(req.body.groupId, req.body.userId))) {
    res.status(401).json('Unauthorized');
  } else {
    let result = await prisma.challenges.update({
      where: {
        id: id,
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
  let id: number = await parseInt(req.params.challengeId);

  let result = await prisma.challengesResult.create({
    data: {
      proof: req.body.image,
      User: {
        connect: {
          id: req.body.userId,
        },
      },
      Challenge: {
        connect: {
          id: id,
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

// should return the points of all players in a challenge, ordered by score descending
app.get('/challenge/:groupId/scoreboard', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);

  let result = await prisma.groups.findFirst({
    where: { id: id },
    include: {
      challenges: {
        include: {
          challengesResults: {
            where: { validated: true },
            select: { User: true, challengesId: true },
          },
        },
      },
    },
  });
  console.log(result);
  // for each user it should tally the total score from the returned validated challenge completions

  // should look something like {playerid: total score}
  res.status(200).json(result);
});

//should get a players points for a specific challenge, for the current week, ordered by date
app.get(
  '/challenge/:challengeId/getplayerpoints',
  auth,
  async (req: any, res: any) => {
    let id: number = await parseInt(req.params.challengeId);
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    let result = await prisma.challengesResult.findMany({
      take: 7,
      where: {
        date: {
          gte: oneWeekAgo,
        },
        challengesId: id,
        usersId: req.body.userid,
      },
      select: { score: true, date: true },
      orderBy: { date: 'desc' },
    });

    res.status(200).json(result);
  },
);

app.post(
  '/challenge/:challengeId/acceptsubmission',
  auth,
  async (req: any, res: any) => {
    let id: number = await parseInt(req.params.challengeId);

    if (!(await isgroupadmin(id, req.body.adminId))) {
      res.status(401).json('Unauthorized');
    }
    prisma.challengesResult.update({
      where: {
        usersId_challengesId: { usersId: req.body.usersId, challengesId: id },
      },
      data: {
        validated: true,
      },
    });
    res.status(200).json('Submission accepted');
  },
);
app.post(
  '/challenge/:challengeId/createvote',
  auth,
  async (req: any, res: any) => {
    let id: number = await parseInt(req.params.challengeId);

    //should allow a group admin to create a vote for a challenge
    await prisma.challenges.update({
      where: {
        id: id,
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
  let id: number = await parseInt(req.params.challengeId);
  if (req.body.vote.type) {
    res.status(400).json('Invalid vote value.');
  }
  let result = await prisma.votes.create({
    data: {
      User: { connect: { id: req.body.userId } },
      Challenge: { connect: { id: id } },
      vote: req.body.vote,
    },
  });
  res.status(200).json(result);
});

const PORT = 3050;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
