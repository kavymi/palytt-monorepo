/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as friendActivity from "../friendActivity.js";
import type * as gatherings from "../gatherings.js";
import type * as notifications from "../notifications.js";
import type * as presence from "../presence.js";
import type * as readReceipts from "../readReceipts.js";
import type * as referralLeaderboard from "../referralLeaderboard.js";
import type * as sharedPosts from "../sharedPosts.js";
import type * as typing from "../typing.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  friendActivity: typeof friendActivity;
  gatherings: typeof gatherings;
  notifications: typeof notifications;
  presence: typeof presence;
  readReceipts: typeof readReceipts;
  referralLeaderboard: typeof referralLeaderboard;
  sharedPosts: typeof sharedPosts;
  typing: typeof typing;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
