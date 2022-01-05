export const getUnixTimeNowInSec = () => Math.floor(Date.now() / 1000);
export const getUnixTimeAfterMins = (mins: number) =>
  getUnixTimeNowInSec() + mins * 60;
