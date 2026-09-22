#!/bin/sh

# herdr ships in omarchy-base.packages today; this keeps it installed if Omarchy ever drops it.
echo "Installing herdr..."
yay -S --noconfirm --needed herdr
