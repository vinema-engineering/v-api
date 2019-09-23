import * as express from 'express';
import {UserController} from '../controllers/user.controller';

let user = new UserController();

const router = express.Router();

router.post('/', user.signUp);

export default router;
