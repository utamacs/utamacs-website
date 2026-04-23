// RFC 7807 Problem Details response
export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail: string;
  instance?: string;
}

export function normalizeError(err: unknown, instance?: string): Response {
  const problem = toProblem(err, instance);
  return new Response(JSON.stringify(problem), {
    status: problem.status,
    headers: { 'Content-Type': 'application/problem+json' },
  });
}

function toProblem(err: unknown, instance?: string): ProblemDetails {
  if (err instanceof Error) {
    const status = (err as Error & { status?: number }).status ?? 500;
    const code = (err as Error & { code?: string }).code ?? 'INTERNAL_ERROR';
    return {
      type: `https://utamacs.org/errors/${code.toLowerCase()}`,
      title: httpTitle(status),
      status,
      detail: status < 500 ? err.message : 'An internal error occurred',
      ...(instance ? { instance } : {}),
    };
  }
  return {
    type: 'https://utamacs.org/errors/internal_error',
    title: 'Internal Server Error',
    status: 500,
    detail: 'An unexpected error occurred',
    ...(instance ? { instance } : {}),
  };
}

function httpTitle(status: number): string {
  const titles: Record<number, string> = {
    400: 'Bad Request',
    401: 'Unauthorized',
    403: 'Forbidden',
    404: 'Not Found',
    409: 'Conflict',
    422: 'Unprocessable Entity',
    429: 'Too Many Requests',
    500: 'Internal Server Error',
    501: 'Not Implemented',
  };
  return titles[status] ?? 'Error';
}
