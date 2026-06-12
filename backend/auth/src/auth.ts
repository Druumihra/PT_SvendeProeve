import nodeCrypto, { KeyObject } from 'node:crypto';
import express from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import cors from 'cors';
import { prisma } from '../lib/prisma';
import fs from 'node:fs';

const app = express();
app.use(express.json());
var dynamicCorsOptions = function (req: any, callback: any) {
  var corsOptions;
  if (req.path.startsWith('/API/')) {
    corsOptions = {
      origin: `${process.env.API_URL}`,
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

function readPrivateKey(filePath: string) {
  return nodeCrypto.createPrivateKey(fs.readFileSync(filePath, 'utf8'));
}

function readPublicKey(filePath: string) {
  return nodeCrypto.createPublicKey(fs.readFileSync(filePath, 'utf8'));
}
const test = () => {
  try {
    const privateKey = readPrivateKey('./private.pem');
    const publicKey = readPublicKey('./public.pem');
    return { privateKey, publicKey };
  } catch (err) {
    const { privateKey, publicKey } = nodeCrypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    fs.writeFile(
      'private.pem',
      privateKey.export({ type: 'pkcs1', format: 'pem' }),
      (err) => {
        if (err) {
          console.error('Error writing private key:', err);
        } else {
          console.log('Private key saved to private.pem');
        }
      },
    );
    fs.writeFile(
      'public.pem',
      publicKey.export({ type: 'spki', format: 'pem' }),
      (err) => {
        if (err) {
          console.error('Error writing public key:', err);
        } else {
          console.log('Public key saved to public.pem');
        }
      },
    );
    return { privateKey, publicKey };
  }
};

const { privateKey, publicKey } = test();

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
  const token = await createJWT(user.name, user.id, sessionId, privateKey);
  res.status(200).cookie('session', token).json({ message: 'Success', token });
});

let auth = async (req: any) => {
  console.log(req.headers);
  const token = req.headers['cookie'].split('session=')[1];
  let decoded = await jwt.verify(token, publicKey);
  if (typeof decoded == 'string') {
    return { valid: false, data: null };
  } else {
    let result = await prisma.sessions.findFirst({
      where: {
        userId: decoded.id,
        sessionId: decoded.data.session,
      },
    });
    if (result != null) {
      return { valid: true, data: result.sessionId, userId: result.userId };
    } else {
      return { valid: false, data: null };
    }
  }
};

app.post('/logout', async (req: any, res: any) => {
  if (!req.headers['cookie']) {
    res.status(400).json('Missing cookie');
  } else {
    let result = await auth(req);
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
      res.status(403).json('Unauthorized');
    }
  }
});

app.post('/createUser', async (req: any, res: any) => {
  if (!req.body.username || !req.body.password) {
    return res.status(400).json('Please fill out all required fields.');
  }

  const usercheck = await prisma.users.findFirst({
    where: { name: req.body.username, email: req.body.email },
  });
  if (usercheck) {
    return res.status(400).json('User already exists.');
  }

  const password = bcrypt.hashSync(req.body.password, 10);

  await prisma.users.create({
    data: {
      name: req.body.username,
      password: password,
      email: req.body.email,
    },
  });

  let user = await prisma.users.findFirst({
    where: { name: req.body.username },
    select: { id: true, name: true },
  });
  if (user == null) {
    res.status(500).json('User failed to create');
  } else {
    try {
      const response = await fetch(`${process.env.API_URL}/auth/createUser`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          username: user.name,
          id: user.id,
        }),
      });
      if (!response.ok) {
        prisma.users.delete({
          where: { id: user!.id },
        });
        return res
          .status(500)
          .json('An error occurred elsewhere while creating the user.');
      } else {
        res.status(201).json('Success');
      }
    } catch (error) {
      let test = await prisma.users.delete({
        where: { id: user.id },
      });
      console.log(error);
      res.status(500).json(test);
    }
  }
});

app.put('/edit/user/', async (req: any, res: any) => {
  if (!req.headers['cookie']) {
    res.status(400).json('Missing cookie');
  } else {
    let result = await auth(req);
    if (result.valid && result.data != null) {
      res.status(401).json('Unauthorized');
    } else {
      await prisma.users.update({
        where: { id: result.userId! },
        data: {
          name: req.body.username,
          password: bcrypt.hashSync(req.body.password, 10),
          email: req.body.email,
        },
      });
      return res.status(200).json('Success');
    }
    res.status(500).json('An error occurred while updating the user.');
  }
});

app.delete('/deleteUser', async (req: any, res: any) => {
  if (!req.headers['cookie']) {
    res.status(400).json('Missing cookie');
  } else {
    let result = await auth(req);
    if (result.valid && result.data != null) {
      try {
        console.log(result.userId);
        let response = await fetch(
          `${process.env.API_URL}/auth/delete/${result.userId}/User`,
          {
            method: 'DELETE',
            headers: {
              'Content-Type': 'application/json',
              cookie: req.headers['cookie'],
            },
          },
        );

        if (!response.ok) {
          res.status(500).json(`An error occured ${await response.json()}`);
        } else {
          let queryres = await prisma.users.delete({
            where: { id: result.userId! },
          });
          if (queryres != null) {
            res.status(200).json('User successfully deleted');
          } else {
            res.status(400).json('error');
          }
        }
      } catch (err) {
        console.log(err);
      }
    } else {
      res.status(401).json('Unauthorized');
    }
  }
});

app.post('/API/verify', async (req: any, res: any) => {
  console.log(1);
  let result = await auth(req);
  if (!result.valid) {
    return res.status(400).json('Unauthorized');
  } else {
    res.status(200).json('Authorized');
  }
});

// setup so it reads public key from file and then responds with it
app.get('/API/getPublicKey', async (req: any, res: any) => {
  res
    .status(200)
    .json(publicKey.export({ type: 'spki', format: 'pem' }).toString());
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
