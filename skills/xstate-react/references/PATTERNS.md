# xState React Patterns

This reference covers advanced xState patterns for React applications, including async operations, guards, parallel
states, and persistence.

## Async Operations with `fromPromise`

Use `fromPromise` to create actor logic from async functions:

```typescript
import { fromPromise, createMachine, assign } from "xstate";

type UserData = {
  id: string;
  name: string;
  email: string;
};

type FetchContext = {
  user: UserData | null;
  error: string | null;
};

type FetchEvent = { type: "FETCH"; userId: string } | { type: "RETRY" };

const userMachine = createMachine({
  types: {} as {
    context: FetchContext;
    events: FetchEvent;
  },
  id: "userFetch",
  initial: "idle",
  context: { user: null, error: null },
  states: {
    idle: {
      on: {
        FETCH: "loading"
      }
    },
    loading: {
      invoke: {
        src: fromPromise(async ({ input }: { input: { userId: string } }) => {
          const response = await fetch(`/api/users/${input.userId}`);
          if (!response.ok) throw new Error("Failed to fetch");
          return response.json() as Promise<UserData>;
        }),
        input: ({ event }) => ({
          userId: (event as { userId: string }).userId
        }),
        onDone: {
          target: "success",
          actions: assign({
            user: ({ event }) => event.output,
            error: null
          })
        },
        onError: {
          target: "error",
          actions: assign({
            error: ({ event }) => (event.error as Error).message
          })
        }
      }
    },
    success: {
      on: {
        FETCH: "loading"
      }
    },
    error: {
      on: {
        RETRY: "loading",
        FETCH: "loading"
      }
    }
  }
});
```

### Cancellation with AbortSignal

`fromPromise` provides an `AbortSignal` for cleanup:

```typescript
const fetchWithCancel = fromPromise(async ({ input, signal }) => {
  const response = await fetch(`/api/data/${input.id}`, { signal });
  return response.json();
});
```

When the actor is stopped or a new invocation starts, the signal is aborted automatically.

## Context Updates with `assign`

Update context immutably using the `assign` action:

```typescript
import { assign, createMachine } from "xstate";

type CounterContext = {
  count: number;
  history: number[];
};

type CounterEvent =
  | { type: "INCREMENT"; by?: number }
  | { type: "DECREMENT" }
  | { type: "RESET" };

const counterMachine = createMachine({
  types: {} as {
    context: CounterContext;
    events: CounterEvent;
  },
  context: { count: 0, history: [] },
  on: {
    INCREMENT: {
      actions: assign({
        count: ({ context, event }) => context.count + (event.by ?? 1),
        history: ({ context }) => [...context.history, context.count]
      })
    },
    DECREMENT: {
      actions: assign({
        count: ({ context }) => context.count - 1,
        history: ({ context }) => [...context.history, context.count]
      })
    },
    RESET: {
      actions: assign({
        count: 0,
        history: []
      })
    }
  }
});
```

### Partial Updates

Update only specific context properties:

```typescript
// Only updates 'count', leaves 'history' unchanged
actions: assign({
  count: ({ context }) => context.count + 1
});
```

### Functional Updates

Access both context and event in updates:

```typescript
actions: assign(({ context, event }) => ({
  count: context.count + (event.by ?? 1),
  lastEvent: event.type
}));
```

## Guards (Conditional Transitions)

Guards determine if a transition should occur:

```typescript
import { setup, assign } from "xstate";

type FormContext = {
  attempts: number;
  isValid: boolean;
};

type FormEvent = { type: "SUBMIT" } | { type: "VALIDATE"; valid: boolean };

const formMachine = setup({
  types: {} as {
    context: FormContext;
    events: FormEvent;
  },
  guards: {
    canSubmit: ({ context }) => context.isValid && context.attempts < 3,
    hasExceededAttempts: ({ context }) => context.attempts >= 3
  }
}).createMachine({
  context: { attempts: 0, isValid: false },
  initial: "editing",
  states: {
    editing: {
      on: {
        VALIDATE: {
          actions: assign({
            isValid: ({ event }) => event.valid
          })
        },
        SUBMIT: [
          {
            guard: "hasExceededAttempts",
            target: "locked"
          },
          {
            guard: "canSubmit",
            target: "submitting"
          },
          {
            // Default: increment attempts
            actions: assign({
              attempts: ({ context }) => context.attempts + 1
            })
          }
        ]
      }
    },
    submitting: {
      // ...
    },
    locked: {
      type: "final"
    }
  }
});
```

### Inline Guards

For simple conditions, use inline guards:

```typescript
on: {
  SUBMIT: {
    guard: ({ context }) => context.isValid,
    target: "submitting"
  }
}
```

### Guard with Event Data

Access event data in guards:

```typescript
guards: {
  isAdminAction: ({ context, event }) =>
    context.userRole === "admin" && event.requiresAdmin === true;
}
```

## Parallel States

Model independent concurrent state regions:

```typescript
import { createMachine, assign } from "xstate";

type EditorContext = {
  content: string;
  isBold: boolean;
  isItalic: boolean;
  isSaving: boolean;
};

type EditorEvent =
  | { type: "TYPE"; text: string }
  | { type: "TOGGLE_BOLD" }
  | { type: "TOGGLE_ITALIC" }
  | { type: "SAVE" }
  | { type: "SAVE_SUCCESS" }
  | { type: "GO_ONLINE" }
  | { type: "GO_OFFLINE" };

const editorMachine = createMachine({
  types: {} as {
    context: EditorContext;
    events: EditorEvent;
  },
  id: "editor",
  type: "parallel",
  context: {
    content: "",
    isBold: false,
    isItalic: false,
    isSaving: false
  },
  states: {
    // Formatting region (independent)
    formatting: {
      type: "parallel",
      states: {
        bold: {
          initial: "off",
          states: {
            off: { on: { TOGGLE_BOLD: "on" } },
            on: { on: { TOGGLE_BOLD: "off" } }
          }
        },
        italic: {
          initial: "off",
          states: {
            off: { on: { TOGGLE_ITALIC: "on" } },
            on: { on: { TOGGLE_ITALIC: "off" } }
          }
        }
      }
    },
    // Save region (independent)
    persistence: {
      initial: "idle",
      states: {
        idle: {
          on: { SAVE: "saving" }
        },
        saving: {
          entry: assign({ isSaving: true }),
          on: {
            SAVE_SUCCESS: {
              target: "idle",
              actions: assign({ isSaving: false })
            }
          }
        }
      }
    },
    // Network region (independent)
    network: {
      initial: "online",
      states: {
        online: {
          on: { GO_OFFLINE: "offline" }
        },
        offline: {
          on: { GO_ONLINE: "online" }
        }
      }
    }
  }
});
```

### Checking Parallel States

Use `state.matches()` with object syntax:

```typescript
// Check if bold is on
state.matches({ formatting: { bold: "on" } });

// Check multiple regions
state.matches({
  formatting: { bold: "on" },
  network: "online"
});
```

## History States

Remember and return to the previous state:

```typescript
const paymentMachine = createMachine({
  id: "payment",
  initial: "method",
  states: {
    method: {
      initial: "card",
      states: {
        card: {
          on: { SELECT_BANK: "bank" }
        },
        bank: {
          on: { SELECT_CARD: "card" }
        },
        hist: { type: "history" }
      },
      on: { NEXT: "review" }
    },
    review: {
      on: { BACK: "method.hist" } // Returns to last method state
    }
  }
});
```

### Deep History

Use `history: "deep"` to remember nested states:

```typescript
hist: {
  type: "history",
  history: "deep"
}
```

## Actor Communication

### Spawning Child Actors

Create dynamic child actors:

```typescript
import { createMachine, assign, spawn } from "xstate";

const todoMachine = createMachine({
  // Individual todo logic
});

const todoListMachine = createMachine({
  context: {
    todos: [] as Array<{ id: string; ref: any }>
  },
  on: {
    ADD_TODO: {
      actions: assign({
        todos: ({ context, event, spawn }) => [
          ...context.todos,
          {
            id: event.id,
            ref: spawn(todoMachine, { id: event.id })
          }
        ]
      })
    },
    REMOVE_TODO: {
      actions: assign({
        todos: ({ context, event }) =>
          context.todos.filter((todo) => todo.id !== event.id)
      })
    }
  }
});
```

### Sending Events to Child Actors

```typescript
import { sendTo } from "xstate";

const parentMachine = createMachine({
  // ...
  on: {
    UPDATE_CHILD: {
      actions: sendTo(
        ({ context }) => context.childRef,
        ({ event }) => ({ type: "UPDATE", data: event.data })
      )
    }
  }
});
```

## Persistence and Rehydration

### Saving State

Save the actor's persisted snapshot:

```typescript
const actor = createActor(machine);
actor.start();

// Get persisted state
const persistedState = actor.getPersistedSnapshot();
localStorage.setItem("machine-state", JSON.stringify(persistedState));
```

### Rehydrating State

Restore from saved state:

```typescript
import { useMachine } from "@xstate/react";

function App() {
  const savedState = localStorage.getItem("machine-state");
  const snapshot = savedState ? JSON.parse(savedState) : undefined;

  const [state, send] = useMachine(machine, {
    snapshot // Rehydrate from saved state
  });

  // Save on state changes
  useEffect(() => {
    const subscription = actor.subscribe((state) => {
      localStorage.setItem(
        "machine-state",
        JSON.stringify(state.toJSON())
      );
    });
    return () => subscription.unsubscribe();
  }, []);

  return <div>{/* ... */}</div>;
}
```

## Delayed Transitions

Use `after` for time-based transitions:

```typescript
const notificationMachine = createMachine({
  initial: "visible",
  states: {
    visible: {
      after: {
        3000: "hidden" // Auto-hide after 3 seconds
      },
      on: {
        DISMISS: "hidden"
      }
    },
    hidden: {
      type: "final"
    }
  }
});
```

### Dynamic Delays

Define delays based on context:

```typescript
const machine = setup({
  delays: {
    retryDelay: ({ context }) => Math.min(1000 * Math.pow(2, context.retries), 10000)
  }
}).createMachine({
  states: {
    error: {
      after: {
        retryDelay: "retrying"
      }
    }
  }
});
```

## Testing with `waitFor`

Wait for specific state conditions in tests:

```typescript
import { createActor, waitFor } from "xstate";
import { describe, it, expect } from "vitest";

describe("fetchMachine", () => {
  it("should reach success state", async () => {
    const actor = createActor(fetchMachine);
    actor.start();

    actor.send({ type: "FETCH", userId: "123" });

    const successState = await waitFor(
      actor,
      (state) => state.matches("success"),
      { timeout: 5000 }
    );

    expect(successState.context.user).toBeDefined();
  });
});
```

## State Matching Patterns

### Simple Match

```typescript
state.matches("loading"); // true if in "loading" state
```

### Hierarchical Match

```typescript
state.matches({ auth: "loggedIn" }); // true if in auth.loggedIn
```

### Using Tags

Add semantic tags to states:

```typescript
const machine = createMachine({
  states: {
    loading: {
      tags: ["loading"]
    },
    fetching: {
      tags: ["loading"]
    },
    success: {
      tags: ["loaded"]
    }
  }
});

// Check by tag
state.hasTag("loading"); // true for loading OR fetching
```

## Common Patterns Summary

| Pattern            | Use Case                       | Key API                            |
| ------------------ | ------------------------------ | ---------------------------------- |
| **Async fetch**    | API calls with loading/error   | `fromPromise`, `invoke`            |
| **Context update** | Immutable state changes        | `assign`                           |
| **Conditional**    | Gate transitions on conditions | `guard`                            |
| **Parallel**       | Independent concurrent regions | `type: "parallel"`                 |
| **History**        | Remember previous state        | `type: "history"`                  |
| **Child actors**   | Dynamic sub-machines           | `spawn`, `sendTo`                  |
| **Persistence**    | Save/restore state             | `getPersistedSnapshot`, `toJSON`   |
| **Delays**         | Time-based transitions         | `after`, `delays`                  |
| **Testing**        | Wait for state conditions      | `waitFor`                          |
| **State check**    | Conditional rendering          | `matches`, `hasTag`, `useSelector` |
