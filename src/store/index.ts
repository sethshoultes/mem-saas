import { create } from 'zustand';
import { User, MembershipPlan, ContentItem, UserActivity } from '../types';
import { supabase } from '../lib/supabase';
import { getCurrentUser, getUserActivity } from '../lib/auth';

interface AdminStore {
  currentUser: User | null;
  setCurrentUser: (user: User | null) => void;
  userActivity: UserActivity[];
  setUserActivity: (activity: UserActivity[]) => void;
  isLoading: boolean;
  setIsLoading: (loading: boolean) => void;
  membershipPlans: MembershipPlan[];
  contentItems: ContentItem[];
  fetchMembershipPlans: () => Promise<void>;
  fetchContentItems: () => Promise<void>;
  initializeUser: () => Promise<void>;
}

export const useAdminStore = create<AdminStore>((set) => ({
  currentUser: null,
  setCurrentUser: (user) => set({ currentUser: user }),
  userActivity: [],
  setUserActivity: (activity) => set({ userActivity: activity }),
  isLoading: false,
  setIsLoading: (loading) => set({ isLoading: loading }),
  membershipPlans: [],
  contentItems: [],
  initializeUser: async () => {
    set({ isLoading: true });
    try {
      const user = await getCurrentUser();
      set({ currentUser: user });
      
      if (user) {
        const activity = await getUserActivity(user.id);
        set({ userActivity: activity });
      }
    } catch (error) {
      console.error('Error initializing user:', error);
    } finally {
      set({ isLoading: false });
    }
  },
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