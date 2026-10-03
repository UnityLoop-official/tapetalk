# TapeTalk 📼🦉

**Sing along, learn along!**

TapeTalk è un'app Android (Flutter) per imparare l'inglese con le canzoni:
mentre la musica suona, il testo inglese scorre a tempo e sotto ogni riga
compare la traduzione italiana.

## Funzioni

- Elenco **I miei preferiti** con le copertine dei dischi
- Testo sincronizzato con la musica, riga corrente evidenziata
- Traduzione italiana sotto ogni riga
- Pausa / Play, **Ricomincia** e **velocità** di riproduzione (1× · 0,85× · 0,75×) senza distorcere la voce
- Logo animato: una musicassetta anni '80 che cambia animale (gufo, gatto, orso, topo, coniglio, rana, volpe, maiale, pipistrello, cane, mucca)

## Da dove arrivano i dati

Nel codice non c'è nessun testo di canzone: tutto viene caricato a runtime e salvato in cache sul telefono.

| Cosa | Fonte |
|---|---|
| Audio | Player YouTube incorporato (video ufficiali) |
| Testo sincronizzato | [LRCLIB](https://lrclib.net) |
| Traduzioni | Musixmatch (se configurato per la canzone), altrimenti [MyMemory](https://mymemory.translated.net) |
| Copertine | iTunes Search API |

> ⚠️ Progetto sperimentale per uso personale. La lettura delle traduzioni da
> Musixmatch è provvisoria e non conforme ai loro termini d'uso: non usarla in
> un'app distribuita.

## Avvio

```bash
flutter pub get
flutter run
```

Le canzoni si configurano in `lib/song.dart` (titolo, artista, ID del video YouTube).

## Struttura

- `lib/main.dart` – schermata principale, preferiti, scheda canzone
- `lib/lyrics_screen.dart` – testo sincronizzato e controlli
- `lib/lyrics_service.dart` – testo e traduzioni
- `lib/cover_service.dart` – copertine
- `lib/logo.dart` – logo animali-musicassetta
- `test/icon_render_test.dart` – genera l'icona dell'app dal logo

## Licenza

[MIT](LICENSE)
