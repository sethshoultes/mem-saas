import { create } from 'zustand';
import { User, MembershipPlan, ContentItem } from '../types';
import { User, MembershipPlan, ContentItem } from '../types';
import { supabase } from '../lib/supabase';

interface AdminStore {
  currentUser: User | null;
  setCurrentUser: (user: User | null) => void;
  isLoading: boolean;
  setIsLoading: (loading: boolean) => void;
  membershipPlans: MembershipPlan[];
  contentItems: ContentItem[];
  fetchMembershipPlans: () => Promise<void>;
  fetchContentItems: () => Promise<void>;
  membershipPlans: MembershipPlan[];
  contentItems: ContentItem[];
  fetchMembershipPlans: () => Promise<void>;
  fetchContentItems: () => Promise<void>;
}

export const useAdminStore = create<AdminStore>((set) => ({
  currentUser: null,
  setCurrentUser: (user) => set({ currentUser: user }),
  isLoading: false,
  setIsLoading: (loading) => set({ isLoading: loading }),
  membershipPlans: [],
  contentItems: [],
  fetchMembershipPlans: async () => {
    const { data: plans } = await supabase
      .from('membership_plans')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (plans) {
      set({ membershipPlans: plans });
    }
  },
  fetchContentItems: async () => {
    const { data: items } = await supabase
      .from('content_items')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (items) {
      set({ contentItems: items });
    }
  },
  membershipPlans: [],
  contentItems: [],
  fetchMembershipPlans: async () => {
    const { data: plans } = await supabase
      .from('membership_plans')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (plans) {
      set({ membershipPlans: plans });
    }
  },
  fetchContentItems: async () => {
    const { data: items } = await supabase
      .from('content_items')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (items) {
      set({ contentItems: items });
    }
  },
}));