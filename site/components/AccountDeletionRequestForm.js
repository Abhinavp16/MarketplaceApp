'use client';

import { useState } from 'react';

const initialForm = { name: '', phone: '' };
const indianMobileNumberPattern = /^[6-9]\d{9}$/;

export default function AccountDeletionRequestForm() {
    const [form, setForm] = useState(initialForm);
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [error, setError] = useState('');
    const [successMessage, setSuccessMessage] = useState('');

    function updateField(event) {
        const { name, value } = event.target;
        setForm((current) => ({ ...current, [name]: value }));
    }

    async function handleSubmit(event) {
        event.preventDefault();
        setError('');
        setSuccessMessage('');

        const name = form.name.trim();
        const phone = form.phone.trim();
        if (!name || !phone) {
            setError('Enter a sample full name and a sample mobile number.');
            return;
        }
        if (!indianMobileNumberPattern.test(phone)) {
            setError('Enter a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9.');
            return;
        }

        // Demo: this form is a harmless no-op. Nothing is sent to any server or stored.
        setIsSubmitting(true);
        await new Promise((resolve) => setTimeout(resolve, 400));
        setSuccessMessage('Request received (demo — nothing was submitted, sent or stored).');
        setForm(initialForm);
        setIsSubmitting(false);
    }

    return (
        <form onSubmit={handleSubmit} className="space-y-6 rounded-2xl border border-gray-200 bg-white p-6 shadow-sm" noValidate>
            <div>
                <h2 className="text-2xl font-bold text-text-primary">Submit your request</h2>
                <p className="mt-2 text-sm">Demo form: enter any sample name and 10-digit number. This form does not submit or store anything.</p>
            </div>

            <div className="grid gap-5 sm:grid-cols-2">
                <div>
                    <label htmlFor="deletion-name" className="mb-2 block text-sm font-semibold text-text-primary">Full name</label>
                    <input
                        id="deletion-name"
                        name="name"
                        type="text"
                        autoComplete="name"
                        placeholder="Enter your full name"
                        value={form.name}
                        onChange={updateField}
                        required
                        maxLength={100}
                        className="w-full rounded-xl border border-gray-300 px-4 py-3 text-text-primary outline-none transition placeholder:text-gray-400 focus:border-[#0d9488] focus:ring-2 focus:ring-[#0d9488]/20"
                    />
                </div>
                <div>
                    <label htmlFor="deletion-phone" className="mb-2 block text-sm font-semibold text-text-primary">Registered mobile number</label>
                    <input
                        id="deletion-phone"
                        name="phone"
                        type="tel"
                        inputMode="numeric"
                        autoComplete="tel"
                        placeholder="9000000000"
                        value={form.phone}
                        onChange={updateField}
                        required
                        maxLength={10}
                        className="w-full rounded-xl border border-gray-300 px-4 py-3 text-text-primary outline-none transition placeholder:text-gray-400 focus:border-[#0d9488] focus:ring-2 focus:ring-[#0d9488]/20"
                    />
                </div>
            </div>

            {error && <p role="alert" className="rounded-xl bg-red-50 px-4 py-3 text-sm font-medium text-red-700">{error}</p>}
            {successMessage && <p role="status" className="rounded-xl bg-green-50 px-4 py-3 text-sm font-medium text-green-800">{successMessage}</p>}

            <button
                type="submit"
                disabled={isSubmitting}
                className="rounded-full bg-[#0d9488] px-6 py-3 text-sm font-bold text-white transition hover:bg-[#0f766e] disabled:cursor-not-allowed disabled:opacity-60"
            >
                {isSubmitting ? 'Submitting request…' : 'Submit demo deletion request'}
            </button>
        </form>
    );
}
