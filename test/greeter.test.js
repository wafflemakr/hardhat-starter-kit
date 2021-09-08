const Greeter = artifacts.require("Greeter");

// Traditional Truffle test

contract("Greeter", ([admin, alice, bob, random]) => {
  it("Should return the new greeting once it's changed", async function () {
    const greeter = await Greeter.new("Hello!");
    expect(await greeter.greet()).to.be.equal("Hello!");

    await greeter.setGreeting("Hello, World!", { from: admin });

    expect(await greeter.greet()).to.be.equal("Hello, World!");
  });
});
