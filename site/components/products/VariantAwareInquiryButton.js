import InquiryPopupButton from '@/components/InquiryPopupButton';

export default function VariantAwareInquiryButton({ productName, price = '', details = [], children = 'Inquire About the Product', className = '' }) {
    return (
        <InquiryPopupButton
            productName={productName}
            price={price}
            details={details}
            className={className}
        >
            {children}
        </InquiryPopupButton>
    );
}
