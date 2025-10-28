import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello() {
    return {
      msg: 'Hello world',
      timestamp: this.getDate(),
    };
  }

  private getDate(): string {
    const date = new Date();
    const currentDate = date.toISOString().slice(0, 'yyyy-mm-dd'.length);
    const minutes = date.getMinutes();
    const hour = date.getHours();
    const seconds = date.getSeconds();

    return `${currentDate} ${hour}:${[10, 11, 12].includes(minutes) ? minutes : '0' + minutes}:${seconds}`;
  }
}
