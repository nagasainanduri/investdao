'use client';

import { useState } from 'react';

export default function CreateProposalPage() {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // TODO: Hook in DAO service method
    alert(`Create proposal: ${title}, ${description}`);
  };

  return (
    <form onSubmit={handleSubmit}>
      <h1>Create New Proposal</h1>
      <input
        type="text"
        placeholder="Title"
        value={title}
        onChange={e => setTitle(e.target.value)}
        required
      />
      <textarea
        placeholder="Description"
        value={description}
        onChange={e => setDescription(e.target.value)}
        required
      />
      <button type="submit">Create Proposal</button>
    </form>
  );
}
