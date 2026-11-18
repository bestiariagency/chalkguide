// @ts-check
import eslintConfigPrettier from 'eslint-config-prettier/flat'
import withNuxt from './.nuxt/eslint.config.mjs'

// D64 (F6.19 C8): the article sanitizer (`sanitize-html`, ~55 KB gzip) must never reach a public
// chunk. Only `server/**` and `scripts/**` import it statically; the panel loads it with `import()`
// (see app/composables/useAdminSanitize.ts). Type-only imports are fine.
const SANITIZER_MESSAGE =
  'The sanitizer is server-only (D64). Import it statically only from server/** or scripts/**; the panel uses `await import()` (useAdminSanitize).'

// Prettier owns formatting; eslint-config-prettier turns off any rule that would conflict with it.
// docs/ holds static design mockups (CDN Tailwind globals), not app code.
export default withNuxt({ ignores: ['docs/**'] })
  .append({
    files: ['**/*.{js,mjs,ts,vue}'],
    ignores: ['server/**', 'scripts/**', 'shared/lib/sanitize/**'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          paths: [{ name: 'sanitize-html', message: SANITIZER_MESSAGE, allowTypeImports: true }],
          patterns: [
            {
              group: ['**/lib/sanitize/sanitize-article-*', '#shared/lib/sanitize/sanitize-article-*'],
              message: SANITIZER_MESSAGE,
              allowTypeImports: true,
            },
          ],
        },
      ],
    },
  })
  .append(eslintConfigPrettier)
