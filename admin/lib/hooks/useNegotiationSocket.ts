import { useEffect, useRef, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { getSocketUrl } from '@/lib/api';

interface TypingUser {
  userId: string;
  username: string;
  userRole: 'admin' | 'wholesaler';
}

export function useNegotiationSocket(
  negotiationId: string,
  userId: string,
  username: string,
) {
  const socketRef = useRef<Socket | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [messageRevision, setMessageRevision] = useState(0);
  const [reconnectRevision, setReconnectRevision] = useState(0);
  const [typingUsers, setTypingUsers] = useState<TypingUser[]>([]);
  const [lastAction, setLastAction] = useState<{ kind: string; payload: unknown; at: number } | null>(null);

  useEffect(() => {
    if (!negotiationId || !userId) return;

    const token = typeof window !== 'undefined' ? localStorage.getItem('accessToken') : null;
    if (!token) return;

    let hasConnected = false;
    // Socket host is derived from NEXT_PUBLIC_API_BASE_URL only (throws if unset).
    // The backend authenticates the connection from the JWT sent in `auth`.
    const socket = io(getSocketUrl(), {
      transports: ['websocket'],
      auth: (cb) => cb({ token: localStorage.getItem('accessToken') || token }),
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      // No reconnectionAttempts cap: retries continue indefinitely with the
      // backoff above, so temporary network loss self-heals.
    });

    socket.on('connect', () => {
      setIsConnected(true);
      setTypingUsers([]);
      socket.emit('join-negotiation', {
        negotiationId,
        userId,
        userRole: 'admin',
      });
      if (hasConnected) setReconnectRevision((revision) => revision + 1);
      hasConnected = true;
    });

    socket.on('disconnect', () => {
      setIsConnected(false);
      setTypingUsers([]);
    });

    socket.on('receive-message', (data: { negotiationId?: string }) => {
      if (String(data?.negotiationId || '') !== negotiationId) return;
      setMessageRevision((revision) => revision + 1);
    });

    // Listen for typing indicators
    socket.on('user-typing', (data: TypingUser) => {
      setTypingUsers((prev) => {
        // Remove if already exists, then add (to update timestamp)
        const filtered = prev.filter((u) => u.userId !== data.userId);
        return [...filtered, data];
      });
    });

    socket.on('stop-typing', (data: { userId: string }) => {
      setTypingUsers((prev) => prev.filter((u) => u.userId !== data.userId));
    });

    // Deal lifecycle events emitted by the backend (accept / counter / reject)
    for (const kind of ['negotiation-accepted', 'negotiation-countered', 'negotiation-rejected']) {
      socket.on(kind, (payload: unknown) => {
        const eventNegotiationId = (payload as { negotiationId?: string })?.negotiationId;
        if (eventNegotiationId && String(eventNegotiationId) !== negotiationId) return;
        setLastAction({ kind, payload, at: Date.now() });
      });
    }

    socketRef.current = socket;

    return () => {
      socket.emit('leave-negotiation', {
        negotiationId,
        userId,
        userRole: 'admin',
      });
      socket.removeAllListeners();
      socket.disconnect();
      if (socketRef.current === socket) socketRef.current = null;
    };
  }, [negotiationId, userId]);

  const emitTyping = () => {
    if (!socketRef.current?.connected) return;
    socketRef.current.emit('typing', {
      negotiationId,
      userId,
      username,
      userRole: 'admin',
    });
  };

  const emitStopTyping = () => {
    if (!socketRef.current?.connected) return;
    socketRef.current.emit('stop-typing', {
      negotiationId,
      userId,
    });
  };

  return {
    isConnected,
    messageRevision,
    reconnectRevision,
    typingUsers,
    lastAction,
    emitTyping,
    emitStopTyping,
  };
}
