const { expect } = require("chai");
const { ethers } = require('hardhat');

describe("Tokens with Uniswap", async() => {
    let Token, token;
    let addr1, addr2;
    let weth_token;

    before(async()=>{
        [addr1, addr2] = await ethers.getSigners();
        
        Token = await ethers.getContractFactory("Token");
        token = await Token.deploy(
            'TestToken',
            'TTT', 
            '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'  // uniswap goreli router address
        );
        console.log("Token Contract Address: ", token.address);
    })

    describe("Send Tokens and ETH on Contract", function () {
        it("should send tokens", async function () {
          await expect(token.connect(addr1).transfer(token.address, 10000 * 10**9)).not.to.be.reverted;
        });

        it("should send ETH", async function () {
            await addr1.sendTransaction({
                to: token.address,
                value: ethers.utils.parseEther("100"), // Sends exactly 100 ether
            });
        });

        it("should return the token and ETH balance of Contract before liquidity", async function () {
            console.log("token balance of contract: ", await token.balanceOf(token.address));
            console.log("ETH balance of contract: ", await ethers.provider.getBalance(token.address));
        });
      });


    describe("add Liquidity using contract address", function () {
        it("should add Liquidity", async function () {
            await expect(token.connect(addr1).addLiquidity(100 * 10**9, ethers.utils.parseEther("1"))).not.to.be.reverted;
        });

        it("should return the token and ETH balance of Contract after liquidity", async function () {
            console.log("token balance of contract: ", await token.balanceOf(token.address));
            console.log("ETH balance of contract: ", await ethers.provider.getBalance(token.address));
        });
    });

    describe("get Amounts In And Amounts Out", function () {
        it("should return the AmountsOut", async function () {
            console.log("Amounts Out: ", await token.getAmountsOut(100));
        });
        it("should return the AmountsIn", async function () {
            console.log("Amounts In: ", await token.getAmountsIn(100));
        });
    });


    describe("swap tokens using contract", function () {
        // ***** this function is working fine ******
        // it("should swap tokens", async function () {
        //     const slippageTolerance = 100; // 10% slippage tolerance
        //     const [tokenAmount, ethAmount] = await token.getAmountsOut(10); 
        //     const _tokenAmount =  ethers.utils.parseUnits(String(tokenAmount.toNumber()), 'gwei');
        //     const _ethAmount =  ethers.utils.parseUnits(String(ethAmount.toNumber()), 'gwei');
        //     const adjustedAmountOut = _ethAmount.mul(ethers.BigNumber.from(1000).sub(slippageTolerance)).div(1000);
        //     await expect(token.connect(addr1).swapTokensForEth(_tokenAmount, adjustedAmountOut)).not.to.be.reverted;
        // });

        it("should swap tokens", async function () {
            const tokenAmount =  ethers.utils.parseUnits('10', 'gwei');
            await expect(token.connect(addr1).swapTokensForEth1(tokenAmount)).not.to.be.reverted;
        });

        it("should return the token and ETH balance of Contract after swapping", async function () {
            console.log("token balance of contract: ", await token.balanceOf(token.address));
            console.log("ETH balance of contract: ", await ethers.provider.getBalance(token.address));
        });
    });

})