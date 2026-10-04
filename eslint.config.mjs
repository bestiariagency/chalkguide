// @ts-check
import eslintConfigPrettier from 'eslint-config-prettier/flat'
import withNuxt from './.nuxt/eslint.config.mjs'

// Prettier owns formatting; eslint-config-prettier turns off any rule that would conflict with it.
export default withNuxt().append(eslintConfigPrettier)
