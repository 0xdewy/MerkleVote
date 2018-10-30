var bn = require('bignumber.js');

const ERC20 =  artifacts.require('./ERC20.sol');
const MerkleVote = artifacts.require('./MerkleVote.sol');
const HashHelpers = artifacts.require('./HashHelpers.sol');

contract('MerkleVote', async(accounts) => {

  let root;
  let proof;
  let voteID;

  let WEI = 1000000000000000000;
  let totalSupply = 10000000 * WEI;  // 10 mil

  const user1 = accounts[1];
  const user2 = accounts[2];
  const user3 = accounts[3];
  const user4 = accounts[4];
  const receiveTransfer = accounts[5];

  users = [user1, user2, user3, user4];

  let tokenPerUser = totalSupply / users.length;

  let token;
  let merkleVote;
  let hash;

  let tree;

  it('Deploy erc20', async() => {
    token = await ERC20.new(totalSupply, 'SomeToken', 18, 'ST');
  });

  it('Distribute token equally', async() => {
    for (let i = 0; i < users.length; i++){
      await token.transfer(users[i], tokenPerUser);
      assert.equal(bn(await token.balanceOf(users[i])).eq(tokenPerUser), true);
    }
  });

  it('Deploy hash helper', async() => {
    hash = await HashHelpers.new();
  });


  it('Deploy merkle vote contract', async() => {
    merkleVote = await MerkleVote.new(token.address);
  });

  //           [0xA37]                           (root)
  //    [0x234        0x264]                       (prepareTree)
  // [user1, user2, user3, user4]                 user = sha3(address, balance)
  it('Create new vote', async() => {
    let methodString = "transfer(address, uint256)";
    let methodID = await hash.getMethodID(methodString);
    let parameterHash = await hash.getParameterHash(receiveTransfer, 5000*WEI);
    voteID = await hash.getVoteID(token.address, methodID , parameterHash);
    tree = await merkleVote.prepareTree(users);
    console.log("leafs of tree: ", tree);
    await merkleVote.createVote(users, voteID);
    root = await merkleVote.merkleRoot(voteID);
    assert.equal(await merkleVote.getHash(tree[0], tree[1]), root);
    console.log("merkle root for voteID: ", voteID, "is: ", root);
  });


  it ("Verify merkle tree for user1", async() => {
    let merkleProof = [await hash.leaf(user2, await token.balanceOf(user2))];
    merkleProof[1] = tree[1];
    console.log("merkle proof is: ", merkleProof);
    let leaf = await hash.leaf(user1, await token.balanceOf(user1));
    let valid = await merkleVote.verifyProof(merkleProof, root, leaf);
    assert.equal(valid, true);
  });

});
