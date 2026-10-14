// Knowledge Hub posts (demo placeholders), newest first. Used by the home
// "Latest Insights" section and the /insights listing. All copy is generic and synthetic.
export const insightPosts = [
    {
        href: '/insights/choosing-a-supplier',
        title: 'Choosing a Reliable Supplier: A Demo Checklist',
        category: 'Buying Guide',
        date: 'Demo',
        readTime: '3 min read',
        image: '/demo/insights/insight-1.jpg',
        imageAlt: 'Abstract illustration of a supplier checklist',
        excerpt: 'Placeholder article: a generic checklist for comparing suppliers on quality, pricing, lead times and payment terms.',
    },
    {
        href: '/insights/inventory-basics',
        title: 'Inventory Basics for Growing Distributors',
        category: 'Operations',
        date: 'Demo',
        readTime: '4 min read',
        image: '/demo/insights/insight-2.jpg',
        imageAlt: 'Abstract illustration of warehouse inventory',
        excerpt: 'Placeholder article: simple, generic habits for tracking stock levels, reorder points and slow-moving items.',
    },
    {
        href: '/insights/bulk-ordering-tips',
        title: 'Bulk Ordering Tips for Dealers and Retailers',
        category: 'Dealer Tips',
        date: 'Demo',
        readTime: '3 min read',
        image: '/demo/insights/insight-3.jpg',
        imageAlt: 'Abstract illustration of bulk order cartons',
        excerpt: 'Placeholder article: generic tips for planning larger orders, negotiating volume pricing and scheduling deliveries.',
    },
];

export function getInsightPost(href) {
    return insightPosts.find((post) => post.href === href);
}
