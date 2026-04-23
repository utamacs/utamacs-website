/// <reference path="../.astro/types.d.ts" />

import type { UserClaims } from './lib/services/interfaces/IAuthService';

declare namespace App {
  interface Locals {
    user?: UserClaims;
  }
}
