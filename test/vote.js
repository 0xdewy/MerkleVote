var bn = require('bignumber.js');


const ERC20 =  artifacts.require('./ERC20.sol');
const MerkleVote = artifacts.require('./MerkleVote.sol');
const HashHelpers = artifacts.require('./HashHelpers.sol');

function getIndex(array, item){
    for (let i=0; i < array.length; i++){
        if (array[i] == item) { return i; }
    }
    throw "leaf is not found in leafs";
}

// TODO: root isn't matching what is created by this algorithm.
async function createTree (merkleVote, leafs) {
    if (leafs.length < 2) { throw "there are not enough leafs"; }
    if (leafs.length == 2) { return await merkleVote.getHash(leafs[0], leafs[1]); }
    let tree = {};
    let layer = leafs;
    let height = Math.floor(Math.log2(leafs.length));
    console.log("height of tree is: " , height);
    for (let i=0; i <= height; i++){
        layer = await merkleVote.hashLayer(layer);
        tree[i] = layer;
        console.log("adding layer to tree: ", layer);
    }
    return tree;
}

async function getSiblings (merkleVote, leafs, root, leaf) {
    let siblings = []
    let computedHash;
    let index = getIndex(leafs, leaf);
    let tree = await createTree(merkleVote, leafs);
    let height = Math.floor(Math.log2(leafs.length));
    console.log("height is: ", height);
    console.log("tree is: ");
    console.log(tree);
    console.log("index is ", index);
    // Leaf is last element???
    if (index == leafs.length -1) {   // If it is the last leaf then sibling is the hash of itself all the way up
        siblings.push(leaf);
        computedHash = leaf;
        for (let i=0; i < height-1; i++){
            computedHash = merkleVote.getHash(computedHash, computedHash);
            siblings.push(computedHash);
        }
        siblings.push(tree[height-1][0])   // push the first node of the layer below root node for final hash
        return siblings;
    }
    else {
        computedHash = leaf;
        for (let i =0; i <= height; i++) {
            index = getIndex(tree[i], computedHash);
            if (index % 2 == 0 ) {       // If index is even number then the next leaf in the list will be the sibling
                siblings.push(tree[i][index+1]);
                computedHash = merkleVote.getHash(computedHash, tree[i][index+1]);
            }
            else {
                siblings.push(tree[i][index-1]);
                computedHash = merkleVote.getHash(computedHash, tree[i][index-1]);
            }
        }
        return siblings;
    }
}

contract('MerkleVote', async(accounts) => {

  let root;
  let proof;
  let voteID;

  let wei = 1000000000000000000;
  let totalSupply = bn(10000000).times(1000000000000);  // 10 mil

  let vote = {};

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const user3 = accounts[3];
  const user4 = accounts[4];
  const receiveTransfer = accounts[5];

  users = [user1, user2, user3, user4];

  let tokenPerUser = totalSupply.div(users.length);

  let token;
  let merkleVote;
  let hash;

  let leafs;

  it('Deploy erc20', async() => {
    token = await ERC20.new(totalSupply, "SomeToken", 18, "ST");
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
    merkleVote = await MerkleVote.new();
  });

  //           [0xA37]                           (root)
  //    [0x234        0x264]                       (prepareTree)
  // [user1, user2, user3, user4]                 user = sha3(address, balance)
  it('Create new vote', async() => {
    let methodString = "transfer(address, uint256)";
    let methodID = await hash.getMethodID(methodString);
    let parameterHash = await hash.getParameterHash(receiveTransfer, bn(5000).times(1000000000000));
    voteID = await hash.getVoteID(token.address, methodID , parameterHash);
    leafs = await merkleVote.hashRawData(token.address, users);
    console.log("leaf leafs: ", leafs);
    await merkleVote.createVote(token.address, users, voteID);
    console.log("vote id is: ", vote.voteID);
    vote = await merkleVote.votes(voteID);
    assert.equal(vote.token, token.address);
    console.log("merkle root for voteID: ", voteID, "is: ", vote.root);
  });


  // it ("Verify merkle leafs for user1", async() => {
  //   let merkleProof = [await hash.leaf(user2, await token.balanceOf(user2))];
  //   merkleProof[1] = leafs[1];
  //   console.log("merkle proof is: ", merkleProof);
  //   let leaf = await hash.leaf(user1, await token.balanceOf(user1));
  //   let valid = await merkleVote.verifyProof(merkleProof, root, leaf);
  //   assert.equal(valid, true);
  // });


  it ("test sibling creation for user1", async() => {
      let leaf = await hash.leaf(user1, await token.balanceOf(user1));
      console.log("user 1 leaf ", leaf);
      console.log("all leafs ", leafs);
      console.log(await getSiblings(merkleVote, leafs, root, leaf));
  });
});
