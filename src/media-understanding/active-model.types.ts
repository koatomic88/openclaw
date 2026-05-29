// Active model selection passed from chat/runtime into media-understanding.
/** Provider/model pair currently active for media-understanding fallback. */
export type ActiveMediaModel = {
  provider: string;
  model?: string;
};
