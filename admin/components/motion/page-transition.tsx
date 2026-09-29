"use client"

import { AnimatePresence, MotionConfig, motion } from "framer-motion"
import type { ReactNode } from "react"

type PageTransitionProps = {
  children: ReactNode
  routeKey: string
}

export function PageTransition({ children, routeKey }: PageTransitionProps) {
  return (
    <MotionConfig reducedMotion="user" transition={{ duration: 0.18, ease: "easeOut" }}>
      <AnimatePresence initial={false} mode="wait">
        <motion.div
          key={routeKey}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -4 }}
        >
          {children}
        </motion.div>
      </AnimatePresence>
    </MotionConfig>
  )
}
