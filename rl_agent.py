import os
from godot_rl.envs.godot_env import GodotEnv
from stable_baselines3 import PPO

env = GodotEnv(env_path=None, show_window=True, speedup=8)

model = PPO(
    "MultiInputPolicy",
    env,
    verbose=1,
    learning_rate=0.0003,
    n_steps=2048,
    batch_size=64,
    ent_coef=0.01
)

print("--- Starting Training: Connection Established ---")
try:
    model.learn(total_timesteps=100000)
    print("--- Training Complete! ---")
except KeyboardInterrupt:
    print("--- Training Interrupted: Saving progress... ---")

# 4. SAVE THE BRAIN
model.save("monopoly_ai_brain")
print("Model saved as 'monopoly_ai_brain.zip'")

# Close the connection
env.close()