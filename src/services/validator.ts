import * as Validator from 'validatorjs'
// import {RULES} from '../utilities/constant';
import { logger } from '../config/winston'

class ValidatorService {
  constructor() {
    logger.info(`Instance of service '${this.constructor.name}' created!`)
  }

  /**
   * General | For performing general validations with defined rules
   * @param data
   * @param rule
   * @returns {Validator}
   */
  public general(data, rule) {
    return new Validator(data, rule)
  }

  public blocksPayload(data) {
    return new Validator(data, {})
  }

  public fails(): boolean {
    return Validator.fails()
  }
}

export default ValidatorService
