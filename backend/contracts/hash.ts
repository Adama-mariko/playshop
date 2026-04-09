declare module '@ioc:Adonis/Core/Hash' {
  interface HashersList {
    argon: {
      implementation: ArgonContract
      config: ArgonConfig
    }
    bcrypt: {
      implementation: BcryptContract
      config: BcryptConfig
    }
  }
}
