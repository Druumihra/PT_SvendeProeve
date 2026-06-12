import express from 'express';
import cors from 'cors';
import { prisma } from '../lib/prisma';
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/client';

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
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(400).json('Please log in');
  }

  const token = authHeader.split(' ')[1];

  if (!token) {
    return res.status(400).json('Please log in');
  }
  try {
    const response = await fetch(`${process.env.AUTH_URL}/API/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
    });
    if (!response.ok) {
      return res.status(403).json('Unauthorized');
    } else {
      next();
    }
  } catch (err) {
    return res.status(500).json('Auth service error');
  }
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

  try {
    await prisma.users.update({
      where: { id: id },
      data: {
        name: req.body.username,
        profilepicture: req.body.picture,
      },
    });

    if (req.body.email || req.body.password) {
      let response = await fetch(`${process.env.AUTH_URL}/edit/user`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          include: 'credentials',
          Authorization: req.headers['cookie'],
        },
        body: JSON.stringify({
          username: req.body.username,
          email: req.body.email,
          password: req.body.password,
        }),
      });
      if (!response.ok) {
        res.status(500).json('Error from Auth');
      }
    }
    res.status(200).json('Success');
  } catch (e) {
    if (e instanceof PrismaClientKnownRequestError) {

      res.status(500).json('internal error');
    }
  }
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
  try {
    let result = await prisma.users.findMany({
      where: {
        name: { contains: req.params.query },
      },
    });
    res.status(200).json(result);
  } catch (e) {
    if (e instanceof PrismaClientKnownRequestError) {
      res.status(500).json('internal error');
    }
  }
});

app.get('/user/getUser/:id', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.id);
  let result = await prisma.users.findUnique({
    where: { id: id },
  });
  if (result == null) {
    res.status(400).json('No user found');
  } else {
    res.status(200).json(result);
  }
});

app.post('/user/addFriend', auth, async (req: any, res: any) => {
  try {
    let result = await prisma.users.update({
      where: { id: req.body.usersId },
      data: {
        friends: {
          create: {
            friendof: { connect: { id: req.body.friendId } },
          },
        },
      },
    });
    res.status(200).json('Friend request sent.');
  } catch (e) {
    if (e instanceof PrismaClientKnownRequestError) {
      if (e.code === 'P2002') {
        res.status(400).json('Request already pending');
      } else {
        res.status(400).json('Unable to send friend request');
      }
    }
  }
});

app.put('/user/acceptFriend', auth, async (req: any, res: any) => {
  let result = await prisma.users.update({
    where: {
      id: req.body.userId,
    },
    data: {
      friends: {
        update: {
          where: {
            usersId_friendid: {
              usersId: req.body.userId,
              friendid: req.body.friendId,
            },
          },
          data: { accepted: true },
        },
      },
    },
  });

  res.status(200).json('Friend request accepted.');
});

app.delete('/user/removeFriend', auth, async (req: any, res: any) => {
  try {
    let result = await prisma.users.update({
      where: {
        id: req.body.userId,
      },
      data: {
        friends: {
          delete: {
            usersId_friendid: {
              usersId: req.body.userId,
              friendid: req.body.friendId,
            },
          },
        },
      },
    });
    res.status(200).json('Friend removed.');
  } catch (e) {
    res.status(500).json(e);
  }
});

app.post('/user/getFriendRequests', auth, async (req: any, res: any) => {
  try {
    const friends = await prisma.friends.findMany({
      where: {
        friendid: req.body.id,
        accepted: false,
      },
      include: {
        user: { select: { id: true, name: true } },
      },
      omit: { usersId: true, friendid: true },
    });
    res.status(200).json(friends);
  } catch (e) {
    res.status(400).json(e);
  }
});

app.post('/user/getFriends', auth, async (req: any, res: any) => {
  try {
    const friends = await prisma.friends.findMany({
      where: {
        usersId: req.body.id,
        accepted: true,
      },
      include: {
        friendof: { select: { id: true, name: true } },
      },
      omit: { accepted: true, usersId: true, friendid: true },
    });
    res.status(200).json(friends);
  } catch (e) {
    res.status(400).json(e);
  }
});

app.post('/group/create', await auth, async (req: any, res: any) => {
  if (!req.body) {
    res.status(400).json('Please fill out all required fields.');
  }
  try {
    let result = await prisma.groups.create({
      data: {
        name: req.body.groupName,
        admins: {
          create: { usersId: req.body.userId },
        },
        members: {
          create: { usersId: req.body.userId },
        },
      },
    });

    if (result === null || result === undefined) {
      res.status(500).json('An error occurred while creating the group.');
    } else {
      res.status(200).json('Group created successfully.');
    }
  } catch (e) {
    if (e instanceof PrismaClientKnownRequestError) {
      res.status(500);
    }
  }
});

app.get('/user/:id/getgroups', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.id);
  let result = await prisma.groupMembers.findMany({
    where: { usersId: id },
    include: {
      group: { select: { name: true } },
    },
    omit: { usersId: true },
  });
  if (result == null) {
    res.status(200).json('Not a part of any groups');
  }
  res.status(200).json(result);
});
app.get('/group/:groupId/getMembers', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);
  const members = await prisma.groups.findUnique({
    where: { id: id },
    include: {
      members: {
        omit: { usersId: true, groupsId: true },
        include: { member: { omit: { profilepicture: true } } },
      },
    },
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
  let result = await prisma.users.update({
    where: {
      id: req.body.userId,
    },
    data: {
      groups: {
        create: {
          group: {
            connect: { id: id },
          },
        },
      },
    },
  });
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
  let result = await prisma.users.update({
    where: { id: req.body.userId },
    data: {
      admin: {
        create: {
          group: {
            connect: { id: id },
          },
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
  let result = await prisma.groupMembers.delete({
    where: {
      usersId_groupsId: {
        groupsId: id,
        usersId: req.body.userId,
      },
    },
  });
  if (await isgroupadmin(id, req.body.userId)) {
    await prisma.groupAdmins.delete({
      where: {
        usersId_groupsId: {
          groupsId: id,
          usersId: req.body.userId,
        },
      },
    });
  }
  res.status(200).json('User successfully deleted');
});

app.post('/group/:groupId/delete', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.groupId);

  if (!(await isgroupadmin(id, req.body.adminId))) {
    res.status(401).json('Unauthorized');
  }
  if (!req.body) {
    res.status(400).json('Invalid request body.');
  }
  let result = await prisma.groups.delete({
    where: {
      id: id,
    },
  });
  res.status(200).json('Group successfully deleted');
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
      description: req.body.description,
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
      id: id,
    },
    include: { challenges: true },
  });
  res.status(200).json(challenges);
});

app.put('/challenge/:challengeId/edit', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.challengeId);

  if (!req.body) {
    res.status(400).json('Invalid request body.');
  }
  let result = await prisma.challenges.update({
    where: {
      id: id,
    },
    data: {
      score: req.body.score,
      name: req.body.challengeName,
      description: req.body.description,
    },
  });

  res.status(200).json(result);
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

app.delete(
  '/challenge/:challengeId/delete',
  auth,
  async (req: any, res: any) => {
    let id: number = await parseInt(req.params.challengeId);

    if (!(await isgroupadmin(req.body.groupId, req.body.userId))) {
      res.status(401).json('Unauthorized');
    }
    let result = await prisma.challenges.delete({
      where: {
        id: id,
      },
    });
    res.status(200).json('Challenge deleted');
  },
);

app.post('/challenge/:challengeId/submit', auth, async (req: any, res: any) => {
  let id: number = await parseInt(req.params.challengeId);
  let result = await prisma.challengesResult.create({
    data: {
      proof: req.body.image,
      Challenge: {
        connect: { id: id },
      },
      User: {
        connect: { id: req.body.userId },
      },
    },
  });
  if (result === null || result === undefined) {
    res.status(500).json('An error occurred while submitting the result.');
  } else {
    res.status(200).json(result);
  }
});

//WIP
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
            include: { User: true },
          },
        },
      },
    },
  });

  const totals: Record<number, number> = {};

  result?.challenges.forEach((challenge: any) => {
    challenge.challengesResults.forEach((submission: any) => {
      const username = submission.User.name;

      totals[username] = (totals[username] ?? 0) + challenge.score;
    });
  });

  const scoreboard = Object.entries(totals)
    .map(([username, score]) => ({
      username,
      score,
    }))
    .sort((a, b) => b.score - a.score);

  res.status(200).json(scoreboard);
});

//WIP
//should get a players points for a specific challenge, for the current week, ordered by date
app.get(
  '/challenge/:userId/getplayerpoints',
  auth,
  async (req: any, res: any) => {
    let id: number = await parseInt(req.params.userId);
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

    const completions = await prisma.challengesResult.findMany({
      where: {
        usersId: id,
        validated: true,
        date: {
          gte: oneWeekAgo,
        },
      },
      include: {
        Challenge: {
          select: {
            score: true,
          },
        },
      },
    });

    const totalPoints = completions.reduce(
      (sum, completion) => sum + completion.Challenge.score,
      0,
    );

    res.status(200).json(totalPoints);
  },
);

app.post(
  '/challenge/:challengeId/acceptsubmission',
  auth,
  async (req: any, res: any) => {
    let id: number = await parseInt(req.params.challengeId);

    if (!(await isgroupadmin(req.body.groupId, req.body.adminId))) {
      res.status(401).json('Unauthorized');
    } else {
      let result = await prisma.challengesResult.update({
        where: {
          usersId_challengesId: { usersId: req.body.userId, challengesId: id },
        },
        data: {
          validated: true,
        },
      });
      res.status(200).json('Submission accepted');
    }
  },
);

// app.post(
//   '/challenge/:challengeId/createvote',
//   auth,
//   async (req: any, res: any) => {
//     let id: number = await parseInt(req.params.challengeId);

//     //should allow a group admin to create a vote for a challenge
//     await prisma.challenges.update({
//       where: {
//         id: id,
//       },
//       data: {
//         votes: {
//           create: [{ vote: req.body.vote }],
//         },
//       },
//     });
//     res.status(200).json('Vote sucessfully created.');
//   },
// );

// app.post('/challenge/:challengeId/vote', auth, async (req: any, res: any) => {
//   let id: number = await parseInt(req.params.challengeId);
//   if (req.body.vote.type) {
//     res.status(400).json('Invalid vote value.');
//   }
//   let result = await prisma.votes.create({
//     data: {
//       User: { connect: { id: req.body.userId } },
//       Challenge: { connect: { id: id } },
//       vote: req.body.vote,
//     },
//   });
//   res.status(200).json(result);
// });

const PORT = 3050;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
