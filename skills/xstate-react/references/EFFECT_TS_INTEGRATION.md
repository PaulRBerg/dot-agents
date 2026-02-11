# xState + Effect-ts Integration

This reference covers integrating xState state machines with Effect-ts for composable, type-safe side effects.

## Why Combine xState with Effect

xState excels at modeling application logic as state machines. Effect-ts provides:

- **Composable side effects** - Chain operations with `Effect.gen` and pipelines
- **Type-safe error handling** - Errors encoded in the type system, not thrown
- **Dependency injection** - Services and context management
- **Testability** - Pure functions that describe effects, executed separately

The combination yields machines where state transitions are type-safe and side effects are composable and testable.

## Architecture Pattern

Separate Effect implementations from machine definitions:

```
src/
├── effect.ts      # Pure Effect implementations (side effects)
├── machine.ts     # xState machine consuming effects
└── App.tsx        # React component using the machine
```

The machine imports and executes effects in its actions. Effects remain pure and testable in isolation.

## Effect Execution in Actions

Execute effects within xState actions using Effect's run functions:

### Synchronous Execution

Use `Effect.runSync` for effects that complete synchronously:

```typescript
import { setup } from "xstate";
import { Effect } from "effect";
import { onPause } from "./effect";

const machine = setup({
  actions: {
    pauseAudio: ({ context: { audioRef } }) =>
      onPause({ audioRef }).pipe(Effect.runSync),
  },
}).createMachine({
  // ...
});
```

### Asynchronous Execution

Use `Effect.runPromise` for effects that are async:

```typescript
import { setup } from "xstate";
import { Effect } from "effect";
import { onPlay } from "./effect";

const machine = setup({
  actions: {
    playAudio: ({ context: { audioRef, audioContext } }) =>
      onPlay({ audioRef, audioContext }).pipe(Effect.runPromise),
  },
}).createMachine({
  // ...
});
```

## Building Effect Implementations

### Effect.gen for Sequential Composition

Use generator syntax for sequential operations:

```typescript
import { Effect } from "effect";

export const onLoad = ({
  audioRef,
  audioContext,
}: {
  audioRef: HTMLAudioElement;
  audioContext: AudioContext | null;
}): Effect.Effect<LoadSuccess, LoadError> =>
  Effect.gen(function* () {
    if (audioContext === null) {
      return yield* Effect.die("AudioContext is null");
    }

    yield* Effect.promise(() => audioContext.resume());

    const source = yield* Effect.try({
      try: () => audioContext.createMediaElementSource(audioRef),
      catch: () => new LoadError("Failed to create source"),
    });

    source.connect(audioContext.destination);

    return { source };
  });
```

### Effect.try for Error Handling

Wrap synchronous operations that may fail:

```typescript
const createSource = Effect.try({
  try: () => audioContext.createMediaElementSource(audioRef),
  catch: (error) => new CreateSourceError({ cause: error }),
});
```

### Effect.promise for Async Operations

Wrap promises:

```typescript
const resumeContext = Effect.promise(() => audioContext.resume());

const playAudio = Effect.promise(() => audioRef.play());
```

### Effect.sync for Synchronous Side Effects

Execute synchronous side effects:

```typescript
const pauseAudio = Effect.sync(() => {
  audioRef.pause();
});

const logError = (message: string) =>
  Effect.sync(() => {
    console.error(message);
  });
```

### Effect.die for Unrecoverable Errors

Signal fatal errors that should crash:

```typescript
if (audioContext === null) {
  return yield* Effect.die("Required AudioContext is missing");
}
```

## Event Emission from Effects

Emit machine events from within Effect handlers using `self.send()`:

### Using Effect.tap for Success Events

```typescript
import { setup, assign } from "xstate";
import { Effect } from "effect";
import { onLoad } from "./effect";

const machine = setup({
  actions: {
    loadTrack: assign({
      source: ({ context: { audioRef, audioContext }, self }) =>
        onLoad({ audioRef, audioContext }).pipe(
          Effect.tap(({ source }) =>
            Effect.sync(() => self.send({ type: "loaded" }))
          ),
          Effect.map(({ source }) => source),
          Effect.runSync
        ),
    }),
  },
}).createMachine({
  // ...
});
```

### Using Effect.tapError for Error Events

```typescript
const machine = setup({
  actions: {
    loadTrack: ({ context: { audioRef, audioContext }, self }) =>
      onLoad({ audioRef, audioContext }).pipe(
        Effect.tap(() => Effect.sync(() => self.send({ type: "loaded" }))),
        Effect.tapError(({ message }) =>
          Effect.sync(() => self.send({ type: "error", message }))
        ),
        Effect.catchTag("LoadError", () => Effect.void),
        Effect.runPromise
      ),
  },
}).createMachine({
  // ...
});
```

### Using Effect.catchTag for Granular Error Recovery

Handle specific error types differently:

```typescript
onLoad({ audioRef, audioContext }).pipe(
  Effect.catchTag("NetworkError", (error) =>
    Effect.sync(() => self.send({ type: "retry" }))
  ),
  Effect.catchTag("PermissionError", (error) =>
    Effect.sync(() => self.send({ type: "permissionDenied" }))
  ),
  Effect.runPromise
);
```

## Complete Example: Audio Player

### Types (`machine-types.ts`)

```typescript
export type Context = {
  audioRef: HTMLAudioElement;
  audioContext: AudioContext | null;
  trackSource: MediaElementAudioSourceNode | null;
  currentTime: number;
};

export type Events =
  | { type: "play" }
  | { type: "pause" }
  | { type: "restart" }
  | { type: "loaded" }
  | { type: "error"; message: string }
  | { type: "updateTime"; time: number };
```

### Effect Implementations (`effect.ts`)

```typescript
import { Effect } from "effect";

class OnLoadError {
  readonly _tag = "OnLoadError";
  constructor(readonly message: string) {}
}

type OnLoadSuccess = {
  trackSource: MediaElementAudioSourceNode;
};

export const onLoad = ({
  audioRef,
  audioContext,
}: {
  audioRef: HTMLAudioElement;
  audioContext: AudioContext | null;
}): Effect.Effect<OnLoadSuccess, OnLoadError> =>
  Effect.gen(function* () {
    if (audioContext === null) {
      return yield* Effect.fail(new OnLoadError("AudioContext is null"));
    }

    yield* Effect.promise(() => audioContext.resume());

    const trackSource = yield* Effect.try({
      try: () => audioContext.createMediaElementSource(audioRef),
      catch: () => new OnLoadError("Failed to create audio source"),
    });

    trackSource.connect(audioContext.destination);

    return { trackSource };
  });

export const onPlay = ({
  audioRef,
  audioContext,
}: {
  audioRef: HTMLAudioElement;
  audioContext: AudioContext | null;
}): Effect.Effect<void> =>
  Effect.gen(function* () {
    if (audioContext) {
      yield* Effect.promise(() => audioContext.resume());
    }
    yield* Effect.promise(() => audioRef.play());
  });

export const onPause = ({
  audioRef,
}: {
  audioRef: HTMLAudioElement;
}): Effect.Effect<void> =>
  Effect.sync(() => {
    audioRef.pause();
  });

export const onRestart = ({
  audioRef,
}: {
  audioRef: HTMLAudioElement;
}): Effect.Effect<void> =>
  Effect.gen(function* () {
    audioRef.currentTime = 0;
    yield* Effect.promise(() => audioRef.play());
  });
```

### Machine Definition (`machine.ts`)

```typescript
import { setup, assign } from "xstate";
import { Effect } from "effect";
import type { Context, Events } from "./machine-types";
import { onLoad, onPlay, onPause, onRestart } from "./effect";

export const audioPlayerMachine = setup({
  types: {} as {
    context: Context;
    events: Events;
  },
  actions: {
    onPlay: ({ context: { audioRef, audioContext } }) =>
      onPlay({ audioRef, audioContext }).pipe(Effect.runPromise),

    onPause: ({ context: { audioRef } }) =>
      onPause({ audioRef }).pipe(Effect.runSync),

    onRestart: ({ context: { audioRef } }) =>
      onRestart({ audioRef }).pipe(Effect.runPromise),

    onLoad: assign({
      trackSource: ({ context: { audioRef, audioContext }, self }) =>
        onLoad({ audioRef, audioContext }).pipe(
          Effect.tap(() => Effect.sync(() => self.send({ type: "loaded" }))),
          Effect.tapError(({ message }) =>
            Effect.sync(() => self.send({ type: "error", message }))
          ),
          Effect.map(({ trackSource }) => trackSource),
          Effect.catchTag("OnLoadError", () => Effect.succeed(null)),
          Effect.runSync
        ),
    }),

    onUpdateTime: assign({
      currentTime: ({ event }) => (event as { time: number }).time,
    }),
  },
}).createMachine({
  id: "audioPlayer",
  initial: "init",
  context: ({ input }) => ({
    audioRef: input.audioRef,
    audioContext: null,
    trackSource: null,
    currentTime: 0,
  }),
  states: {
    init: {
      on: {
        loaded: "active",
        error: "error",
      },
      entry: "onLoad",
    },
    active: {
      initial: "paused",
      states: {
        paused: {
          on: {
            play: {
              target: "playing",
              actions: "onPlay",
            },
          },
        },
        playing: {
          on: {
            pause: {
              target: "paused",
              actions: "onPause",
            },
            restart: {
              actions: "onRestart",
            },
            updateTime: {
              actions: "onUpdateTime",
            },
          },
        },
      },
    },
    error: {
      type: "final",
    },
  },
});
```

### React Component (`App.tsx`)

```typescript
"use client";

import { useMachine } from "@xstate/react";
import { useRef, useEffect } from "react";
import { audioPlayerMachine } from "./machine";

export function AudioPlayer({ src }: { src: string }) {
  const audioRef = useRef<HTMLAudioElement>(null);

  const [state, send] = useMachine(audioPlayerMachine, {
    input: { audioRef: audioRef.current! },
  });

  useEffect(() => {
    if (!audioRef.current) return;

    const handleTimeUpdate = () => {
      send({ type: "updateTime", time: audioRef.current!.currentTime });
    };

    audioRef.current.addEventListener("timeupdate", handleTimeUpdate);
    return () => {
      audioRef.current?.removeEventListener("timeupdate", handleTimeUpdate);
    };
  }, [send]);

  return (
    <div>
      <audio ref={audioRef} src={src} />

      {state.matches("init") && <p>Loading...</p>}

      {state.matches("error") && <p>Error loading audio</p>}

      {state.matches({ active: "paused" }) && (
        <button onClick={() => send({ type: "play" })}>Play</button>
      )}

      {state.matches({ active: "playing" }) && (
        <>
          <button onClick={() => send({ type: "pause" })}>Pause</button>
          <button onClick={() => send({ type: "restart" })}>Restart</button>
          <p>Time: {state.context.currentTime.toFixed(1)}s</p>
        </>
      )}
    </div>
  );
}
```

## Best Practices

### DO

- **Separate effect implementations** from machine definitions
- **Pass explicit parameters** to effects instead of raw events
- **Use typed errors** with `Effect.fail` and error classes
- **Use `Effect.runSync`** for synchronous effects
- **Use `Effect.runPromise`** for async effects
- **Emit events via `self.send()`** for async completion/error

### DON'T

- **Don't access event directly** in effect implementations
- **Don't throw errors** - use `Effect.fail` or `Effect.die`
- **Don't mix sync and async** in the same Effect chain without understanding the implications
- **Don't forget error handling** - use `catchTag` or `tapError`

## Further Reading

- [XState + Effect Article](https://www.sandromaglione.com/articles/getting-started-with-xstate-and-effect-audio-player)
- [Source Repository](https://github.com/SandroMaglione/getting-started-xstate-and-effect)
