import _ from "lodash"
import { Signer, Wallet } from "ethers"
import { solidity } from "ethereum-waffle"
import { ethers, deployments } from "hardhat"
import { ecsign } from "ethereumjs-util"
import chai from "chai"
import {
  UpToken
} from "../build/typechain"
import { keccak256 } from "@ethersproject/keccak256"
import { chainId, getBlockNumber, getBlockTimestamp, mineBlocks } from "./helpers"

chai.use(solidity)
const { expect } = chai
const { get } = deployments

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
const privateKey = '18259bcf8198b35f3c1e863dab2f1663d1fd0dbe91c13d1a994bee3026ce790f'

describe("UpFarm unit test", () => {
  let owner: Signer
  let alice: Signer
  let bob: Signer
  let cat: Wallet
  let up: UpToken
  let ownerAddress: string
  let aliceAddress: string
  let bobAddress: string

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture()

      const signers = await ethers.getSigners();
      [ owner, alice, bob ] = signers

      cat = new Wallet(privateKey)

      ownerAddress = await owner.getAddress()
      aliceAddress = await alice.getAddress()
      bobAddress = await bob.getAddress()

      up = (await ethers.getContractAt(
        "UpToken",
        (
          await get("UP")
        ).address,
      )) as UpToken

      await up.transfer(aliceAddress, '100000000000000000000')
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("delegates", () => {
    it('should return zero address if not delegated', async () => {
      expect(await up.delegates(aliceAddress)).to.equals(ZERO_ADDRESS)
    })

    it('should return delegatee address', async () => {
      await up.connect(alice).delegate(bobAddress)
      expect(await up.delegates(aliceAddress)).to.equals(bobAddress)
    })
  })

  describe("delegate", () => {
    it('should delegate successfully', async () => {
      await up.connect(alice).delegate(bobAddress)
    })

    it('should be able to change delegatee', async () => {
      await up.connect(alice).delegate(bobAddress)
      expect(await up.delegates(aliceAddress)).to.equals(bobAddress)
      expect(await up.getCurrentVotes(bobAddress)).to.equals('100000000000000000000')
      await up.connect(alice).delegate(aliceAddress)
      expect(await up.delegates(aliceAddress)).to.equals(aliceAddress)
      expect(await up.getCurrentVotes(bobAddress)).to.equals(0)
      expect(await up.getCurrentVotes(aliceAddress)).to.equals('100000000000000000000')
    })
  })

  describe("delegateBySig", () => {
    it('should delegateBySig successfully', async () => {
      const DOMAIN_TYPEHASH = keccak256(Buffer.from("EIP712Domain(string name,uint256 chainId,address verifyingContract)", "utf-8"))
      const DELEGATION_TYPEHASH = keccak256(Buffer.from("Delegation(address delegatee,uint256 nonce,uint256 expiry)", "utf-8"))
      const name = keccak256(Buffer.from("UP Token", "utf-8"))
      const chainid = await chainId()
      const ts = await getBlockTimestamp()
      const nonce = 0
      const expiry = Number(ts) + 100

      const domainSeparatorRaw =
        DOMAIN_TYPEHASH.substring(2) +
        name.substring(2) +
        chainid.toString(16).padStart(64, "0") +
        up.address.substring(2).padStart(64, "0")

      const domainSeparator = keccak256(
        Buffer.from(domainSeparatorRaw, 'hex')
      )

      const structHashRaw =
        DELEGATION_TYPEHASH.substring(2) +
        bobAddress.substring(2).padStart(64, "0") +
        nonce.toString(16).padStart(64, "0") +
        expiry.toString(16).padStart(64, "0")

      const structHash = keccak256(
        Buffer.from(structHashRaw, 'hex')
      )

      const digestRaw =
        '1901' +
        domainSeparator.substring(2) +
        structHash.substring(2)
      const digest = keccak256(
        Buffer.from(digestRaw, 'hex')
      )

      const { r, s, v } = ecsign(Buffer.from(digest.substring(2), "hex"), Buffer.from(privateKey, "hex"))

      await expect(up.delegateBySig(
        bobAddress,
        nonce,
        expiry,
        v,
        r,
        s
      ))
      .emit(up, 'DelegateChanged')
      .withArgs(cat.address, ZERO_ADDRESS, bobAddress)

      expect(await up.delegates(cat.address)).to.equals(bobAddress)
    })
  })

  describe("getCurrentVotes", () => {
    it('should get zero if not delegated', async () => {
      expect(await up.getCurrentVotes(aliceAddress)).to.equals(0)
    })

    it('should get balance as votes if delegated to self', async () => {
      await up.connect(alice).delegate(aliceAddress)
      expect(await up.getCurrentVotes(aliceAddress)).to.equals('100000000000000000000')
    })

    it('should get votes if be delegated to', async () => {
      expect(await up.getCurrentVotes(bobAddress)).to.equals(0)
      await up.connect(alice).delegate(bobAddress)
      expect(await up.getCurrentVotes(bobAddress)).to.equals('100000000000000000000')
    })
  })

  describe("getPriorVotes", () => {
    it('should get history votes successfully', async () => {
        await up.connect(alice).delegate(bobAddress)
        expect(await up.getCurrentVotes(bobAddress)).to.equals('100000000000000000000')
        const bn = await getBlockNumber()
        await up.connect(alice).delegate(aliceAddress)
        expect(await up.getCurrentVotes(bobAddress)).to.equals(0)
        expect(await up.getPriorVotes(bobAddress, bn)).to.equals('100000000000000000000')
    })

    it('should get current votes successfully', async () => {
        expect(await up.getCurrentVotes(bobAddress)).to.equals(0)
        await up.connect(alice).delegate(bobAddress)
        expect(await up.getCurrentVotes(bobAddress)).to.equals('100000000000000000000')
        const bn = await getBlockNumber()
        await mineBlocks(10)
        expect(await up.getPriorVotes(bobAddress, bn)).to.equals('100000000000000000000')
    })
  })
})