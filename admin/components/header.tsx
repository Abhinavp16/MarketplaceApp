"use client"

import { LogOut, Settings2 } from "@/components/hugeicons"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { useEffect, useState } from "react"
import { getUser, logout } from "@/lib/api"
import Link from "next/link"
import Image from "next/image"

export function Header() {
  const [user, setUser] = useState<any>(null)

  useEffect(() => {
    setUser(getUser())
    const handleStorage = () => setUser(getUser())
    window.addEventListener("storage", handleStorage)
    return () => window.removeEventListener("storage", handleStorage)
  }, [])

  return (
    <header className="absolute left-0 right-0 top-0 z-50 flex items-center justify-between border-b border-[#d0d1e3]/80 bg-[#f8f8fd]/78 p-6 backdrop-blur-[28px]">
      <div className="flex items-center gap-2 pl-4 text-xl font-bold tracking-tight text-slate-900">
        <Image src="/icon.svg" alt="TradeHub Demo logo" width={32} height={32} className="h-8 w-8 rounded-lg object-cover" />
        TradeHub Demo <span className="text-indigo-600">Admin</span>
      </div>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button className="group flex items-center gap-3 rounded-full border border-[#d0d1e3] bg-white/90 py-1.5 pl-2 pr-4 shadow-sm transition-colors hover:bg-white focus:outline-none focus:ring-2 focus:ring-[#818cf8]/50 ring-offset-white">
            <Avatar className="h-8 w-8 border border-[#c6c7df] transition-colors group-hover:border-[#818cf8]/50">
              <AvatarImage src={user?.avatar} />
              <AvatarFallback className="bg-gradient-to-br from-[#bec0f4] to-[#5156d7] text-xs font-bold text-slate-900">
                {user?.name?.charAt(0).toUpperCase() || "A"}
              </AvatarFallback>
            </Avatar>
            <div className="flex translate-y-[1px] flex-col items-start">
              <span className="line-clamp-1 text-xs font-bold text-slate-900">{user?.name || "Admin"}</span>
              <span className="text-[10px] font-medium uppercase tracking-wider text-slate-500">Super Admin</span>
            </div>
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-56 border-[#d0d1e3] bg-white p-2 text-slate-900 shadow-xl">
          <DropdownMenuLabel className="mb-2 border-b border-[#e2e2f0] px-3 pb-3 font-normal">
            <div className="flex flex-col space-y-1">
              <p className="text-sm font-bold leading-none text-slate-900">{user?.name || "Administrator"}</p>
              <p className="truncate text-xs leading-none text-slate-500">{user?.email || "Administrator email unavailable"}</p>
            </div>
          </DropdownMenuLabel>
          <Link href="/settings">
            <DropdownMenuItem className="group cursor-pointer rounded-lg px-3 py-2 focus:bg-[#efeff8] focus:text-indigo-700">
              <Settings2 className="mr-3 h-4 w-4 text-slate-500 group-focus:text-indigo-700" />
              <span className="text-sm font-medium">Account Settings</span>
            </DropdownMenuItem>
          </Link>
          <DropdownMenuSeparator className="my-2 bg-[#e2e2f0]" />
          <DropdownMenuItem onClick={() => logout()} className="group cursor-pointer rounded-lg px-3 py-2 focus:bg-red-500/10 focus:text-red-400">
            <LogOut className="mr-3 h-4 w-4 text-slate-500 group-focus:text-red-400" />
            <span className="text-sm font-medium">Logout Session</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </header>
  )
}
