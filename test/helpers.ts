import { ethers } from "hardhat"

async function getBlockNumber() {
  return await ethers.provider.getBlockNumber();
}

async function mineBlocks(n: Number) {
  for (let i = 0; i < n; i++) {
    await ethers.provider.send("evm_mine", []);
  }
}

function getCurrentTimestamp() {
  return Math.floor(new Date().getTime() / 1000);
}

async function getBlockTimestamp() {
  let block = await ethers.provider.getBlock(await getBlockNumber());
  return block.timestamp;
}

async function increaseTime(ts: Number) {
  await ethers.provider.send("evm_increaseTime", [ts]);
}

async function setBlockTime(ts: Number) {
  await ethers.provider.send("evm_setNextBlockTimestamp", [ts]);
}

async function chainId() {
  return (await ethers.provider.getNetwork()).chainId
}

export {
  getBlockNumber,
  mineBlocks,
  getCurrentTimestamp,
  getBlockTimestamp,
  increaseTime,
  setBlockTime,
  chainId
}