import { useCallback, useEffect, useRef, useState } from 'react';
import { errorMessage, PAGE_SIZE } from './api';

export type Loaded<T> = { data: T | null; error: string | null; loading: boolean; reload: () => void };

/** Runs [load] on mount and whenever [deps] change; ignores answers that arrive late. */
export function useLoad<T>(load: () => Promise<T>, deps: unknown[]): Loaded<T> {
  const [state, setState] = useState<{ data: T | null; error: string | null; loading: boolean }>({
    data: null,
    error: null,
    loading: true,
  });
  const [tick, setTick] = useState(0);
  const latest = useRef(0);
  useEffect(() => {
    const mine = ++latest.current;
    setState((s) => ({ ...s, loading: true, error: null }));
    load().then(
      (data) => mine === latest.current && setState({ data, error: null, loading: false }),
      (e) => mine === latest.current && setState({ data: null, error: errorMessage(e), loading: false }),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);
  return { ...state, reload: useCallback(() => setTick((t) => t + 1), []) };
}

export type Paged<T> = {
  rows: T[];
  error: string | null;
  loading: boolean;
  more: boolean;
  loadMore: () => void;
  reload: () => void;
};

/** A list loaded page by page. Changing [deps] (a filter, a search) starts over. */
export function usePaged<T>(load: (offset: number) => Promise<T[]>, deps: unknown[]): Paged<T> {
  const [rows, setRows] = useState<T[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [more, setMore] = useState(false);
  const [tick, setTick] = useState(0);
  const latest = useRef(0);
  const count = useRef(0);

  const fetchPage = useCallback(
    (offset: number, replace: boolean) => {
      const mine = ++latest.current;
      setLoading(true);
      setError(null);
      load(offset).then(
        (page) => {
          if (mine !== latest.current) return;
          setRows((prev) => (replace ? page : [...prev, ...page]));
          count.current = (replace ? 0 : count.current) + page.length;
          setMore(page.length === PAGE_SIZE);
          setLoading(false);
        },
        (e) => {
          if (mine !== latest.current) return;
          setError(errorMessage(e));
          setLoading(false);
        },
      );
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [...deps],
  );

  useEffect(() => {
    count.current = 0;
    fetchPage(0, true);
  }, [fetchPage, tick]);

  return {
    rows,
    error,
    loading,
    more,
    loadMore: () => {
      if (!loading) fetchPage(count.current, false);
    },
    reload: () => setTick((t) => t + 1),
  };
}
