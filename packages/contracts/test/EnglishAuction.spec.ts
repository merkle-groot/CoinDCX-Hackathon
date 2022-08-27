import { expect } from 'chai'
import { ethers } from 'hardhat'
import { EnglishAuction } from '../typechain-types/contracts/EnglishAuction'

describe('English Auction', () => {
  async function deployEnglishAuction() {
    const signers = await ethers.getSigners()
    const factory = await ethers.getContractFactory('EnglishAuction')
    const englishAuctionContract = (await factory.deploy()) as EnglishAuction
  }

  describe('Initialise auction', async () => {})
})
