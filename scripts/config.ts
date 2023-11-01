export const contractAddress = new Map<string, Contract>()

export interface Contract {
    Token: string
    Profile: string
    Race: string
    Registry: string
    Publisher: string
}


contractAddress.set("mumbai", {
    Token: "0x0a2664F0425a43EE03150BAd5751D35678F61d94",
    Profile: "0xA78ef0BF6BbD685e8bAE2E6036bf9e22ebE78621",
    Race: "0x6a9dD3A5314E07afE03577c319fc9293CFa30e5A",
    Registry: "0x0ab9567Ee93b9b6d5470F5671003Bc1549D97BAC",
    Publisher: "0x381C5ed7B1536599149FD5c1c797E73cCE760847",
})