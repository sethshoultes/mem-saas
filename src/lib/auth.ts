import { User } from '../types';
import { supabase } from './supabase';

export async function resetPassword(email: string) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/reset-password`,
  });

  if (error) {
    throw error;
  }
}

export async function signIn(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    throw error;
  }

  return data;
}

export async function deleteUser(userId: string) {
  const { error } = await supabase
    .rpc('delete_user', { target_user_id: userId });

  if (error) {
    throw error;
  }
}

export async function signUp(email: string, password: string, fullName: string) {
  const { data: authData, error: authError } = await supabase.auth.signUp({
    email,
    password,
  });

  if (authError) {
    throw authError;
  }

  if (authData.user) {
    const { error: profileError } = await supabase
      .from('user_profiles')
      .insert({
        id: authData.user.id,
        full_name: fullName,
        role: 'user',
      });

    if (profileError) {
      throw profileError;
    }
  }

  return authData;
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) {
    throw error;
  }
}

export async function getCurrentUser(): Promise<User | null> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    return null;
  }

  try {
    const { data: profile, error } = await supabase
      .rpc('get_accessible_users', { viewer_id: user.id })
      .eq('id', user.id)
      .single();

    if (error) throw error;

    return {
      id: user.id,
      email: user.email!,
      profile: profile || undefined,
    };
  } catch (error) {
    console.error('Error fetching user profile:', error);
    return null;
  }
}

export async function updateUserProfile(userId: string, data: Partial<User['profile']>) {
  const { error } = await supabase
    .from('user_profiles')
    .update(data)
    .eq('id', userId);

  if (error) {
    throw error;
  }

  // Log the activity
  await supabase.rpc('log_user_activity', {
    p_user_id: userId,
    p_action: 'profile_updated',
    p_details: data,
  });
}

export async function getUserActivity(userId: string) {
  const { data, error } = await supabase
    .from('user_activity')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) {
    throw error;
  }

  return data;
}