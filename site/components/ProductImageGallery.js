'use client';

import { useState, useEffect } from 'react';

export default function ProductImageGallery({ images, name, displayPrice }) {
    const galleryImages = images?.length > 0 ? images.slice(0, 4) : [];
    const [isOpen, setIsOpen] = useState(false);
    const [currentIndex, setCurrentIndex] = useState(0);
    const currentDisplayPrice = displayPrice;

    // Lock scroll when lightbox is open
    useEffect(() => {
        if (isOpen) {
            document.body.style.overflow = 'hidden';
        } else {
            document.body.style.overflow = 'unset';
        }
    }, [isOpen]);

    const openLightbox = (index) => {
        setCurrentIndex(index);
        setIsOpen(true);
    };

    const closeLightbox = () => setIsOpen(false);

    const nextImage = (e) => {
        e.stopPropagation();
        setCurrentIndex((prev) => (prev + 1) % galleryImages.length);
    };

    const prevImage = (e) => {
        e.stopPropagation();
        setCurrentIndex((prev) => (prev - 1 + galleryImages.length) % galleryImages.length);
    };

    if (galleryImages.length === 0) return null;

    if (galleryImages.length === 1) {
        return (
            <>
                <div 
                    onClick={() => openLightbox(0)}
                    className="overflow-hidden rounded-[2.5rem] border border-gray-100 bg-white shadow-sm cursor-zoom-in"
                >
                    <div className="relative aspect-[4/5] overflow-hidden bg-white flex items-center justify-center p-2">
                        <img
                            src={galleryImages[0]}
                            alt={name}
                            className="h-full w-full object-contain"
                        />
                        {currentDisplayPrice && (
                            <div className="absolute left-5 bottom-5 rounded-2xl bg-white/92 px-4 py-3 shadow-lg backdrop-blur">
                                <p className="text-[10px] font-bold uppercase tracking-[0.24em] text-gray-400">Price</p>
                                <p className="text-xl font-black text-brand-primary">{currentDisplayPrice}</p>
                            </div>
                        )}
                    </div>
                </div>
                {isOpen && (
                    <Lightbox 
                        images={galleryImages} 
                        currentIndex={currentIndex} 
                        onClose={closeLightbox}
                        onNext={nextImage}
                        onPrev={prevImage}
                    />
                )}
            </>
        );
    }

    return (
        <>
            <div className="overflow-hidden rounded-[2.5rem] border border-gray-100 bg-white p-4 shadow-sm h-full">
                <div className="grid grid-cols-2 gap-3 aspect-[4/5]">
                    {/* Main Large Image */}
                    <div 
                        onClick={() => openLightbox(0)}
                        className={`${galleryImages.length === 2 ? 'col-span-1' : 'col-span-1 row-span-2'} relative overflow-hidden rounded-[1.5rem] bg-neutral-surface/30 group flex items-center justify-center p-2 cursor-zoom-in`}
                    >
                        <img
                            src={galleryImages[0]}
                            alt={`${name} - 1`}
                            className="h-full w-full object-contain transition-transform duration-500 group-hover:scale-105"
                        />
                        {currentDisplayPrice && galleryImages.length > 0 && (
                            <div className="absolute left-4 bottom-4 rounded-xl bg-white/92 px-3 py-2 shadow-lg backdrop-blur-sm z-10">
                                <p className="text-[8px] font-bold uppercase tracking-[0.24em] text-gray-400">Price</p>
                                <p className="text-base font-black text-brand-primary">{currentDisplayPrice}</p>
                            </div>
                        )}
                    </div>

                    {/* Right side images */}
                    <div className="grid grid-rows-2 gap-3">
                        {galleryImages.length === 2 && (
                            <div 
                                onClick={() => openLightbox(1)}
                                className="row-span-2 relative overflow-hidden rounded-[1.5rem] bg-neutral-surface/30 group flex items-center justify-center p-2 cursor-zoom-in"
                            >
                                <img
                                    src={galleryImages[1]}
                                    alt={`${name} - 2`}
                                    className="h-full w-full object-contain transition-transform duration-500 group-hover:scale-105"
                                />
                            </div>
                        )}

                        {galleryImages.length === 3 && (
                            <>
                                <div 
                                    onClick={() => openLightbox(1)}
                                    className="relative overflow-hidden rounded-[1.5rem] bg-neutral-surface/30 group flex items-center justify-center p-2 cursor-zoom-in"
                                >
                                    <img
                                        src={galleryImages[1]}
                                        alt={`${name} - 2`}
                                        className="h-full w-full object-contain transition-transform duration-500 group-hover:scale-105"
                                    />
                                </div>
                                <div 
                                    onClick={() => openLightbox(2)}
                                    className="relative overflow-hidden rounded-[1.5rem] bg-neutral-surface/30 group flex items-center justify-center p-2 cursor-zoom-in"
                                >
                                    <img
                                        src={galleryImages[2]}
                                        alt={`${name} - 3`}
                                        className="h-full w-full object-contain transition-transform duration-500 group-hover:scale-105"
                                    />
                                </div>
                            </>
                        )}

                        {galleryImages.length === 4 && (
                            <>
                                <div 
                                    onClick={() => openLightbox(1)}
                                    className="relative overflow-hidden rounded-[1.5rem] bg-neutral-surface/30 group flex items-center justify-center p-1 cursor-zoom-in"
                                >
                                    <img
                                        src={galleryImages[1]}
                                        alt={`${name} - 2`}
                                        className="h-full w-full object-contain transition-transform duration-500 group-hover:scale-105"
                                    />
                                </div>
                                <div className="grid grid-cols-2 gap-3">
                                    <div 
                                        onClick={() => openLightbox(2)}
                                        className="relative overflow-hidden rounded-[1rem] bg-neutral-surface/30 group flex items-center justify-center p-1 cursor-zoom-in"
                                    >
                                        <img
                                            src={galleryImages[2]}
                                            alt={`${name} - 3`}
                                            className="h-full w-full object-contain transition-transform duration-500 group-hover:scale-105"
                                        />
                                    </div>
                                    <div 
                                        onClick={() => openLightbox(3)}
                                        className="relative overflow-hidden rounded-[1rem] bg-neutral-surface/30 group flex items-center justify-center p-1 cursor-zoom-in"
                                    >
                                        <img
                                            src={galleryImages[3]}
                                            alt={`${name} - 4`}
                                            className="h-full w-full object-contain transition-transform duration-500 group-hover:scale-105"
                                        />
                                    </div>
                                </div>
                            </>
                        )}
                    </div>
                </div>
            </div>
            {isOpen && (
                <Lightbox 
                    images={galleryImages} 
                    currentIndex={currentIndex} 
                    onClose={closeLightbox}
                    onNext={nextImage}
                    onPrev={prevImage}
                />
            )}
        </>
    );
}

function Lightbox({ images, currentIndex, onClose, onNext, onPrev }) {
    useEffect(() => {
        const handleKeyDown = (e) => {
            if (e.key === 'Escape') onClose();
            if (e.key === 'ArrowRight') onNext(e);
            if (e.key === 'ArrowLeft') onPrev(e);
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [onClose, onNext, onPrev]);

    return (
        <div 
            className="fixed inset-0 z-[100] flex items-center justify-center bg-white/98 backdrop-blur-xl transition-all duration-300"
            onClick={onClose}
        >
            {/* Close Button */}
            <button 
                onClick={onClose}
                className="absolute top-6 right-6 z-[110] rounded-full bg-neutral-surface p-3 text-text-primary transition-all hover:bg-gray-100 hover:scale-110 active:scale-95 shadow-sm"
                aria-label="Close"
            >
                <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" />
                </svg>
            </button>

            {/* Navigation Arrows */}
            {images.length > 1 && (
                <>
                    <button 
                        onClick={onPrev}
                        className="absolute left-6 z-[110] rounded-full bg-neutral-surface p-4 text-brand-primary transition-all hover:bg-gray-100 hover:scale-110 active:scale-95 shadow-md lg:left-10"
                        aria-label="Previous image"
                    >
                        <svg className="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M15 19l-7-7 7-7" />
                        </svg>
                    </button>
                    <button 
                        onClick={onNext}
                        className="absolute right-6 z-[110] rounded-full bg-neutral-surface p-4 text-brand-primary transition-all hover:bg-gray-100 hover:scale-110 active:scale-95 shadow-md lg:right-10"
                        aria-label="Next image"
                    >
                        <svg className="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
                        </svg>
                    </button>
                </>
            )}

            {/* Main Image Container */}
            <div 
                className="relative flex h-full w-full items-center justify-center p-8 lg:p-24"
                onClick={(e) => e.stopPropagation()}
            >
                <img
                    src={images[currentIndex]}
                    alt={`Product view ${currentIndex + 1}`}
                    className="max-h-[85vh] max-w-full rounded-[2.5rem] border border-gray-100 object-contain bg-white shadow-[0_30px_60px_-12px_rgba(0,0,0,0.12)] transition-all duration-500 animate-in fade-in zoom-in-95"
                />

                {/* Image Counter */}
                <div className="absolute bottom-10 left-1/2 -translate-x-1/2 rounded-full bg-text-primary px-5 py-2 text-sm font-bold text-white shadow-lg">
                    {currentIndex + 1} / {images.length}
                </div>
            </div>
        </div>
    );
}
