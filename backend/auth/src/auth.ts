import nodeCrypto, { KeyObject } from 'node:crypto';
import express from 'express';
import bcrypt from 'bcrypt';
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

const createKeys = () => {
  const { privateKey, publicKey } = nodeCrypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  return { privateKey, publicKey };
};

const { privateKey, publicKey } = createKeys();

const createJWT = (
  user: string,
  id: number,
  session: number,
  privateKey: KeyObject,
) => {
  const token = jwt.sign(
    {
      data: { user, id, session },
    },
    privateKey,
    { algorithm: 'RS256', expiresIn: '2h' },
  );
  return token;
};

app.post('/login', async (req: any, res: any) => {
  if (!req.body.username || !req.body.password) {
    return res.status(400).json('Please fill out all required fields.');
  }

  const user = await prisma.users.findFirst({
    where: { name: req.body.username },
  });
  if (!user) {
    return res.status(400).json('No user found.');
  }

  if (!bcrypt.compareSync(req.body.password, user.password)) {
    return res.status(400).json('Incorrect password.');
  }
  let sessionId = Math.floor(Math.random() * 1000000000);

  await prisma.sessions.create({
    data: {
      sessionId: sessionId,
      userId: user.id,
      createdAt: Math.floor(Date.now() / (1000 * 60 * 60)),
    },
  });
  const token = createJWT(user.name, user.id, sessionId, privateKey);
  res.status(200).cookie('session', token).json('Success');
});

let auth = async (token: any) => {
  await jwt.verify(token, publicKey, async function (err: any, decoded: any) {
    if (err) {
      return { valid: false, data: null};
    } else {
      let result = await prisma.sessions.findFirst({
        where: {
          userId: decoded.data.id,
          sessionId: decoded.data.session,
        },
      });
      if (result != null) {
        return { valid: true, data: result.sessionId };
      }
      else {
        return { valid: false, data: null};
      }
    }
  });
  return { valid: false, data: null};
};

app.post('/logout', async (req: any, res: any) => {
  const token = req.headers['cookie'].split('session=')[1];
  let result = await auth(token);
      if (result.valid && result.data != null) {
        prisma.sessions.delete({
          where: { sessionId: result.data },
        });

        prisma.sessions.deleteMany({
          where: {
            createdAt: {
              lt: Math.floor(Date.now() / (1000 * 60 * 60) - 2),
            },
          },
        });
        res.status(200).json('Success');
      } else {
        res.status(400).json('Unauthorized');
      }
    }
  );


//should send a call to the api service to create a user there
app.post('/createUser', async (req: any, res: any) => {
  if (!req.body.username || !req.body.password) {
    return res.status(400).json('Please fill out all required fields.');
  }

  const user = await prisma.users.findFirst({
    where: { name: req.body.username },
  });
  if (user) {
    return res.status(400).json('Username already exists.');
  }

  const password = bcrypt.hashSync(req.body.password, 10);

  await prisma.users.create({
    data: {
      name: req.body.username,
      password: password,
      email: req.body.email,
    },
  });

  res.status(200).json('Success');
});

app.post('/verify', async (req: any, res: any) => {
  const token = req.headers['cookie'].split('session=')[1];
  let result = await auth(token);
  if (result.valid) {
    return res.status(400).json('Unauthorized');
  }
  else {
    res.status(200).json('Authorized');
  }
});

app.get('/getPublicKey');

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
