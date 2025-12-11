import axios from 'axios';

const INPUT_EPOCH = 60;
const BEACONCHAIN_API_URL = 'http://136.110.112.90:3500';

const main = async () => {
  const GENESIS_TIME = (await axios.get(`${BEACONCHAIN_API_URL}/eth/v1/beacon/genesis`)).data.data.genesis_time;

  const {SLOTS_PER_EPOCH, SECONDS_PER_SLOT} = (await axios.get(`${BEACONCHAIN_API_URL}/eth/v1/config/spec`)).data.data;

  const SLOTS_TOTAL = INPUT_EPOCH * SLOTS_PER_EPOCH;
  const TIMESTAMP = Number(GENESIS_TIME) + SLOTS_TOTAL * SECONDS_PER_SLOT;

  console.log('TIMESTAMP', TIMESTAMP);

};

main();
