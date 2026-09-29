import * as React from "react"
import { HugeiconsIcon } from "@hugeicons/react"
import * as HugeIconsFree from "@hugeicons/core-free-icons"

type HugeiconsProps = Omit<React.ComponentProps<typeof HugeiconsIcon>, "icon">

type IconCatalog = Record<string, unknown>
const iconCatalog = HugeIconsFree as unknown as IconCatalog

function resolveIcon(names: string[]) {
  return names.map((name) => iconCatalog[name]).find(Boolean) || iconCatalog.AlertCircleIcon || iconCatalog.CircleIcon
}

function createHugeIcon(...names: string[]) {
  const Icon = ({ size = 24, strokeWidth = 1.8, color = "currentColor", ...props }: HugeiconsProps) => (
    <HugeiconsIcon
      icon={resolveIcon(names) as any}
      size={size}
      strokeWidth={strokeWidth}
      color={color}
      {...props}
    />
  )

  Icon.displayName = `HugeIcon(${names[0] || "Fallback"})`
  return Icon
}

export const Loader2 = createHugeIcon("Loading03Icon", "Loading02Icon")
export const Loader2Icon = Loader2
export const Eye = createHugeIcon("ViewIcon", "AiViewIcon")
export const EyeOff = createHugeIcon("ViewOffIcon", "AiViewIcon")
export const Check = createHugeIcon("CheckmarkCircle02Icon", "CheckmarkCircleIcon", "CheckListIcon")
export const CheckIcon = Check
export const CheckCircle2 = createHugeIcon("CheckmarkCircle02Icon", "CheckmarkCircleIcon")
export const BadgeCheck = createHugeIcon("BadgeCheckIcon", "CheckmarkBadge02Icon", "CheckmarkCircle02Icon")
export const X = createHugeIcon("Cancel01Icon", "CancelIcon")
export const XIcon = X
export const XCircle = createHugeIcon("CancelCircleIcon", "CancelSquareIcon")
export const History = createHugeIcon("WorkHistoryIcon", "TransactionHistoryIcon")
export const Plus = createHugeIcon("Add01Icon", "AddIcon")
export const Pencil = createHugeIcon("PencilEdit01Icon", "Edit02Icon", "EditIcon")
export const Edit2 = Pencil
export const Trash2 = createHugeIcon("Delete02Icon", "Delete01Icon", "DeleteIcon")
export const Save = createHugeIcon("FloppyDiskIcon", "SaveIcon")
export const Upload = createHugeIcon("Upload01Icon", "CloudUploadIcon")
export const Download = createHugeIcon("Download01Icon", "CloudDownloadIcon")
export const Search = createHugeIcon("Search01Icon", "AiSearchIcon")
export const SearchIcon = Search
export const Filter = createHugeIcon("FilterIcon", "FilterMailIcon")
export const RefreshCw = createHugeIcon("Refresh01Icon", "RefreshIcon")
export const Power = createHugeIcon("PowerServiceIcon", "PowerIcon")
export const Settings = createHugeIcon("Settings01Icon")
export const SettingsIcon = Settings
export const Menu = createHugeIcon("Menu01Icon")
export const MenuIcon = Menu
export const MoreHorizontal = createHugeIcon("MoreHorizontalIcon", "More01Icon")
export const MoreHorizontalIcon = MoreHorizontal
export const GripVertical = createHugeIcon("HandGripIcon", "DragDropVerticalIcon")
export const GripVerticalIcon = GripVertical
export const Crown = createHugeIcon("CrownIcon", "Crown02Icon")
export const Star = createHugeIcon("StarIcon", "FavouriteIcon")
export const Flame = createHugeIcon("FireIcon", "FlameKindlingIcon")
export const AlertTriangle = createHugeIcon("Alert01Icon", "AlertIcon")
export const Activity = createHugeIcon("Activity01Icon", "ActivityIcon")
export const TrendingUp = createHugeIcon("ChartIncreaseIcon", "ArrowUpRight01Icon")
export const ArrowUp = createHugeIcon("ArrowUp01Icon", "ArrowUpIcon")
export const ArrowDown = createHugeIcon("ArrowDown01Icon", "ArrowDownIcon")
export const ArrowLeft = createHugeIcon("ArrowLeft01Icon", "ArrowLeftIcon")
export const ArrowRight = createHugeIcon("ArrowRight01Icon", "ArrowRightIcon")
export const ArrowUpRight = createHugeIcon("ArrowUpRight01Icon", "ArrowUpRightIcon")
export const ArrowDownRight = createHugeIcon("ArrowDownRight01Icon", "ArrowDownRightIcon")
export const ArrowUpDown = createHugeIcon("ArrowUpDownIcon", "ArrowDataTransferVerticalIcon")
export const ChevronDown = createHugeIcon("ArrowDown01Icon", "ArrowDownIcon")
export const ChevronDownIcon = ChevronDown
export const ChevronUp = createHugeIcon("ArrowUp01Icon", "ArrowUpIcon")
export const ChevronUpIcon = ChevronUp
export const ChevronLeft = createHugeIcon("ArrowLeft01Icon", "ArrowLeftIcon")
export const ChevronLeftIcon = ChevronLeft
export const ChevronRight = createHugeIcon("ArrowRight01Icon", "ArrowRightIcon")
export const ChevronRightIcon = ChevronRight
export const ChevronsUpDown = ArrowUpDown
export const Circle = createHugeIcon("CircleIcon", "RadioButtonIcon")
export const CircleIcon = Circle
export const Square = createHugeIcon("SquareIcon", "CheckboxIcon")
export const CheckSquare = createHugeIcon("CheckListIcon", "CheckboxIcon")
export const MinusIcon = createHugeIcon("MinusSignIcon", "Minus01Icon")
export const Package = createHugeIcon("Package01Icon", "PackageIcon")
export const ShoppingCart = createHugeIcon("ShoppingCart01Icon")
export const ShoppingBag = createHugeIcon("ShoppingBag01Icon")
export const Truck = createHugeIcon("DeliveryTruckIcon", "TruckIcon", "DeliveryBox01Icon")
export const Building2 = createHugeIcon("Building01Icon")
export const FolderTree = createHugeIcon("Folder01Icon", "Folder02Icon")
export const FolderPlus = createHugeIcon("FolderAddIcon")
export const Globe = createHugeIcon("Globe02Icon", "GlobeIcon")
export const ImageIcon = createHugeIcon("Image01Icon", "Image02Icon")
export const Image = ImageIcon
export const ImagePlus = createHugeIcon("ImageAdd01Icon", "ImageAddIcon")
export const LayoutGrid = createHugeIcon("GridViewIcon", "Layout01Icon")
export const List = createHugeIcon("LeftToRightListBulletIcon", "ListViewIcon")
export const Link = createHugeIcon("Link01Icon", "Link02Icon")
export const Languages = createHugeIcon("LanguageCircleIcon", "LanguageSquareIcon")
export const Tag = createHugeIcon("Tag01Icon", "TagIcon")
export const Tags = createHugeIcon("TagsIcon", "Tag01Icon")
export const User = createHugeIcon("UserIcon", "UserCircleIcon")
export const Users = createHugeIcon("UserGroupIcon", "UserMultiple02Icon")
export const UserPlus = createHugeIcon("UserAdd01Icon", "AddTeamIcon")
export const UserSearch = createHugeIcon("UserSearch01Icon", "AiSearchIcon")
export const Phone = createHugeIcon("Call02Icon", "PhoneIcon", "AiPhoneIcon")
export const Mail = createHugeIcon("Mail01Icon", "AiMailIcon")
export const Bell = createHugeIcon("Notification01Icon", "BellDotIcon")
export const Send = createHugeIcon("SentIcon", "MailSend01Icon")
export const MessageSquare = createHugeIcon("Message01Icon", "BubbleChatIcon")
export const MessageCircle = createHugeIcon("Message02Icon", "BubbleChatIcon")
export const Headphones = createHugeIcon("HeadphonesIcon", "HeadphoneIcon")
export const ShieldCheck = createHugeIcon("Shield01Icon", "Shield02Icon")
export const CircleDollarSign = createHugeIcon("DollarCircleIcon", "BadgeDollarSignIcon")
export const IndianRupee = createHugeIcon("RupeeIcon", "BadgeIndianRupeeIcon")
export const Wrench = createHugeIcon("Wrench01Icon", "WrenchIcon")
export const MapPin = createHugeIcon("Location01Icon", "MapPinIcon")
export const Clock3 = createHugeIcon("Clock01Icon")
export const Clock = Clock3
export const RefreshCcw = RefreshCw
export const Settings2 = Settings
export const LogOut = createHugeIcon("Logout01Icon", "LogoutCircleIcon")
export const MapPinned = createHugeIcon("Location01Icon", "MapPinIcon")
export const ExternalLink = ArrowUpRight
export const Handshake = createHugeIcon("HandshakeIcon", "Agreement01Icon")
export const Wallet = createHugeIcon("Wallet01Icon", "WalletIcon")
export const Youtube = createHugeIcon("YoutubeIcon")
export const PanelLeftIcon = createHugeIcon("PanelLeftIcon", "PanelLeftOpenIcon")
