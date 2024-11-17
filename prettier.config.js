module.exports = {
  overrides: [
    // {
    //   files: '*.ts',
    //   options: {
    //     semi: false,
    //     singleQuote: true,
    //     trailingComma: 'none'
    //   }
    // }
    {
      files: '*.sol',
      options: {
        printWidth: 160,
        tabWidth: 4,
        useTabs: false,
        singleQuote: false,
        bracketSpacing: false
      }
    }
  ]
}
