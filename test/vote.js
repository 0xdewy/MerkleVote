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

function getRandomUser(users){
    if (users.length == 0) throw "no users supplied to getRandomUser";
    let randomNumber = Math.floor((Math.random() * users.length));
    console.log("random number is ", randomNumber);
    return users[randomNumber];
}


async function createTree (merkleVote, leafs) {
    console.log("the length of the leafs are: ", leafs.length);
    let tree = {};
    let layer = leafs;
    let height = Math.ceil(Math.log2(leafs.length));
    console.log("height of tree is: " , height);
    tree[0] = leafs;
    for (let i=1; i <= height; i++){
        layer = await merkleVote.hashLayer(layer);
        tree[i] = layer;
        // console.log("adding layer to tree: ", layer);
    }
    return tree;
}

async function getSiblings (merkleVote, leafs, leaf) {
    let siblings = [];
    let computedHash;
    console.log("getting siblings");
    if (leafs.length < 2) { throw "there are not enough leafs"; }
    let index = getIndex(leafs, leaf);
    console.log("index of leaf is: ", leafs);
    if (leafs.length == 2) {
        if (index == 1) {
            siblings.push(leafs[0]);
            return siblings;
        }
        else {
            siblings.push(leafs[1]);
            return siblings;
        }
    }
    let tree = await createTree(merkleVote, leafs);
    let height = Math.ceil(Math.log2(leafs.length));
    console.log("tree is: ");
    console.log(tree);
    // Leaf is last element???
    if (index == leafs.length -1 && index % 2 == 0) {   // If it is the last leaf then sibling is the hash of itself all the way up
        console.log("last element and odd number of leafs");
        siblings.push(leaf);
        computedHash = leaf;
        for (let i=0; i < height; i++){
            computedHash = await merkleVote.getHash(computedHash, computedHash);
            siblings.push(computedHash);
        }
        siblings.push(tree[height-1][0])   // push the first node of the layer below root node for final hash
        console.log("siblings are: ", siblings);
        return siblings;
    }
    else {
        computedHash = leaf;
        console.log("looking for sibling of ", computedHash);
        for (let i=0; i < height; i++) {
            index = getIndex(tree[i], computedHash);
            if (index % 2 == 0 ) {       // If index is even number then the next leaf in the list will be the sibling
                if (index == leafs.length -1) { throw "last element should always be odd index"; }
                siblings.push(tree[i][index+1]);
                // console.log("sibling is: ", tree[i][index+1])
                computedHash = await merkleVote.getHash(computedHash, tree[i][index+1]);
                // console.log("now need to find sibling for: ", computedHash);
            }
            else {
                siblings.push(tree[i][index-1]);
                // console.log("sibling is: ", tree[i][index-1]);
                computedHash = await merkleVote.getHash(computedHash, tree[i][index-1]);
            }
        }
        console.log("siblings are: ", siblings);
        return siblings;
    }
}

// Just iterating this simple test with random number generation for now.
for (let index=0; index < 3; index++){
    contract('MerkleVote', async(accounts) => {


      const TOTALSUPPLY = bn(10000000).times(1000000000000);  // 10 mil


      // Voting variables
      let vote = {};
      let users = [];
      let root;
      let proof;
      let voteID;
      let firstVoter;

      // Contracts
      let token;
      let merkleVote;
      let hash;

      let leafs;

        it("Setup users", function() {
            let rand = Math.floor(Math.random() * (accounts.length-1)) + 3;
            if (rand > accounts.length) throw "random number generated is higher than account number";
            for (let i=1; i < rand; i++) {
                users[i-1] = accounts[i];
            }
            console.log("user length: ", users.length);
            console.log("users are: ", users);
        });

      // describe('It deploys and distributes tokens equally to users', function() {

          it('Deploy erc20', async() => {
            token = await ERC20.new(TOTALSUPPLY, "SomeToken", 18, "ST");
          });

          it('Distribute token equally', async() => {
            for (let i = 0; i < users.length; i++){
              await token.transfer(users[i], 10000000000000);
              assert.equal(bn(await token.balanceOf(users[i])).eq(10000000000000), true);
            }
          });

          it('Deploy hash helper', async() => {
            hash = await HashHelpers.new();
          });


          it('Deploy merkle vote contract', async() => {
            merkleVote = await MerkleVote.new();
          });
      // });


      it('Create new vote', async() => {
        firstVoter = getRandomUser(users);
        console.log("firstVoter is: ", firstVoter);
        let methodString = "transfer(address, uint256)";
        let methodID = await hash.getMethodID(methodString);
        let parameterHash = await hash.getParameterHash(firstVoter, bn(5000).times(1000000000000));
        voteID = await hash.getVoteID(token.address, methodID , parameterHash);
        leafs = await merkleVote.hashRawData(token.address, users);
        let leaf = await hash.leaf(firstVoter, await token.balanceOf(firstVoter));
        console.log("leaf of first voter is: ", firstVoter);
        console.log("leafs: ", leafs);
        let tx = await merkleVote.createVote(token.address, users, voteID);
        console.log("gas used creating vote: ", tx.receipt.gasUsed);
        console.log("vote id is: ", voteID);
        vote = await merkleVote.votes(voteID);
        assert.equal(vote.token, token.address);
        console.log("merkle root for voteID: ", voteID, "is: ", vote.root);
      });

      it ("test sibling creation for firstVoter", async() => {
          let leaf = await hash.leaf(firstVoter, await token.balanceOf(firstVoter));
          console.log("finding siblings for firstVoter leaf ", leaf);
          let siblings =  await getSiblings(merkleVote, leafs, leaf);
          console.log("siblings: ", siblings);
          let valid = await merkleVote.verifyProof(siblings, vote.root, leaf);
      });


    });
};
