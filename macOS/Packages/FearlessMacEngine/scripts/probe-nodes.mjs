// Run with Node 22 or later. Redirect stdout to retain the dated evidence.
import { readFileSync } from "node:fs";

const sourceURL = new URL("../../../../remote-config/production/chains/v13/chains.json", import.meta.url);
const source = JSON.parse(readFileSync(sourceURL, "utf8"));
const names = ["Polkadot", "Polkadot AssetHub", "Kusama", "Kusama AssetHub", "Westend", "Ethereum", "BNB Smart Chain", "Polygon"];
const chains = names.map(name => {
    const chain = source.find(candidate => candidate.name === name);
    if (!chain) throw new Error("Missing source chain: " + name);
    return chain;
});

// These Westend RPCs appear in polkadot-js/apps' testingRelayWestend registry.
chains.find(chain => chain.name === "Westend").nodes.push(
    { name: "OnFinality", url: "wss://westend.api.onfinality.io/public-ws" },
    { name: "Dwellir", url: "wss://westend-rpc.n.dwellir.com" }
);
for (const chain of chains.filter(chain => chain.chainId.length === 64)) {
    const parity = chain.nodes.find(node => node.name === "Parity node");
    if (parity) chain.nodes.push({ name: "Parity HTTPS", url: parity.url.replace("wss:", "https:") });
}
chains.push({
    name: "Sepolia",
    chainId: "11155111",
    nodes: [
        { name: "PublicNode", url: "https://ethereum-sepolia-rpc.publicnode.com" },
        { name: "DRPC", url: "https://sepolia.drpc.org" }
    ]
});

async function request(url, body) {
    if (url.startsWith("https:")) {
        const response = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body,
            signal: AbortSignal.timeout(12_000)
        });
        if (!response.ok) throw new Error("HTTP " + response.status);
        return (await response.json()).result;
    }
    return new Promise((resolve, reject) => {
        const socket = new WebSocket(url);
        const timer = setTimeout(() => finish(reject, new Error("Timed out")), 12_000);
        function finish(callback, value) {
            clearTimeout(timer);
            socket.onclose = socket.onerror = null;
            socket.close();
            callback(value);
        }
        socket.onopen = () => socket.send(body);
        socket.onmessage = event => {
            try { finish(resolve, JSON.parse(event.data).result); }
            catch { finish(reject, new Error("Invalid JSON")); }
        };
        socket.onerror = () => finish(reject, new Error("WebSocket connection failed"));
        socket.onclose = () => finish(reject, new Error("Socket closed"));
    });
}

async function probe(chain, node) {
    const evm = /^\d+$/.test(chain.chainId) && chain.chainId.length < 12;
    const method = evm ? "eth_chainId" : "chain_getBlockHash";
    const expected = "0x" + (evm ? BigInt(chain.chainId).toString(16) : chain.chainId);
    const row = { chain: chain.name, ...node, method, expected };
    try {
        const result = await request(node.url, JSON.stringify({ jsonrpc: "2.0", id: 1, method, params: evm ? [] : [0] }));
        return { ...row, result, verified: typeof result === "string" && result.toLowerCase() === expected };
    } catch (error) {
        return { ...row, verified: false, error: error.message };
    }
}

const probes = await Promise.all(chains.flatMap(chain => chain.nodes.map(node => probe(chain, node))));
console.log(JSON.stringify({ date: new Date().toISOString(), probes }, null, 2));
