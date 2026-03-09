# Contributing

Obrigado por contribuir com o Debian Setup Kit.

## Fluxo recomendado

1. Crie branch a partir de `main`
2. Faça mudanças pequenas e objetivas
3. Rode os checks locais
4. Abra PR com descrição clara

## Checks locais mínimos

```bash
bash -n setup.sh lib/*.sh
shellcheck setup.sh lib/*.sh
./setup.sh --all --dry-run
```

## Convenção de commit (sugestão)

- `feat: ...` nova funcionalidade
- `fix: ...` correção de bug
- `docs: ...` documentação
- `refactor: ...` reorganização sem mudar comportamento
- `style: ...` ajuste visual/formato

## Regras importantes

- Não incluir segredos (tokens/chaves/.env)
- Preservar compatibilidade de flags existentes
- Se mudar comportamento, atualizar README e CHANGELOG
