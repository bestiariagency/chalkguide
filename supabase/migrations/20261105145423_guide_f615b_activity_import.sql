-- F6.15b (D50): acciones del registro para la importación de fichas. Va sola: un valor nuevo de enum
-- no se puede usar en la misma transacción en que se añade.
alter type guide.activity_action add value if not exists 'import';
alter type guide.activity_action add value if not exists 'import_undo';
